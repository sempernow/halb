
# Service type LoadBalancer

## TL;DR

Enterprise on-prem teams typically do not use LoadBalancer type Service.
They rather expose their applications exclusively through Ingress, 
provisioning subdomains per service; __`<svc>.kube.lime.local`__.

# Q:

On-prem Solution builting upon existing HALB project

# A:

Looking at your actual config (https://github.com/sempernow/halb/blob/master/haproxy.cfg.tpl), you need something that:

1. Watches K8s Service type LoadBalancer
2. Allocates a VIP
3. Generates HAProxy backend/frontend config
4. Triggers HAProxy reload

This is actually **way simpler** than what I was describing. Here are your real options:

## Option 1: Extend HAProxy Kubernetes Ingress Controller

HAProxy already has an ingress controller, but you want LoadBalancer type services, not Ingress resources. However, **HAProxy Enterprise Kubernetes Ingress Controller** has "external mode" which is exactly your use case:That's for Ingress resources, not Service type LoadBalancer. Let me give you the practical options for your actual setup:

## Option 1: Simple Cloud Provider Pattern (Recommended)

Write a minimal cloud controller that:

1. Watches Service type LoadBalancer
2. Allocates VIP from ConfigMap pool
3. **Generates HAProxy config snippet** to /etc/haproxy/conf.d/
4. Signals HAProxy reload

**Implementation sketch:**

```go
// Minimal CCM for halb
type HalbController struct {
    clientset kubernetes.Interface
    ipPool    *IPPool
    configDir string  // /etc/haproxy/conf.d/
}

func (h *HalbController) ReconcileService(svc *v1.Service) error {
    if svc.Spec.Type != v1.ServiceTypeLoadBalancer {
        return nil
    }
    
    // Allocate VIP
    vip := h.ipPool.AllocateOrGet(svc)
    
    // Get NodePorts (halb will point to these)
    nodePorts := getNodePorts(svc)
    nodes := h.getClusterNodes()
    
    // Generate HAProxy config
    config := fmt.Sprintf(`
frontend lb-%s
    bind %s:%d
    mode tcp
    default_backend lb-%s-backend

backend lb-%s-backend
    mode tcp
    balance roundrobin
`, svc.Name, vip, svc.Spec.Ports[0].Port, svc.Name, svc.Name)
    
    for _, node := range nodes {
        config += fmt.Sprintf("    server %s %s:%d check\n", 
            node.Name, node.Status.Addresses[0].Address, nodePorts[0])
    }
    
    // Write config file
    ioutil.WriteFile(
        filepath.Join(h.configDir, fmt.Sprintf("%s.cfg", svc.Name)),
        []byte(config),
        0644,
    )
    
    // Reload HAProxy
    exec.Command("systemctl", "reload", "haproxy").Run()
    
    // Update Service status
    svc.Status.LoadBalancer.Ingress = []v1.LoadBalancerIngress{
        {IP: vip},
    }
    h.clientset.CoreV1().Services(svc.Namespace).UpdateStatus(ctx, svc, metav1.UpdateOptions{})
    
    return nil
}
```

**Pros:**

- Simple (~300 lines total)
- No Data Plane API needed
- Works with your existing halb setup
- Easy to debug (just check generated configs)

**Cons:**

- Still relies on NodePort (kube-proxy does pod distribution)
- HAProxy reloads on every change

## Option 2: Operator Pattern with Templates

Use controller-runtime to build an operator:

```go
// Use your existing haproxy.cfg.tpl as the base template
type ServiceReconciler struct {
    client.Client
    Scheme    *runtime.Scheme
    Template  *template.Template
}

func (r *ServiceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    var svc corev1.Service
    if err := r.Get(ctx, req.NamespacedName, &svc); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }
    
    // Gather all LoadBalancer services
    allServices := r.gatherAllLoadBalancerServices()
    
    // Render complete haproxy.cfg from template
    config, err := r.Template.Execute(allServices)
    
    // Write and reload
    ioutil.WriteFile("/etc/haproxy/haproxy.cfg", config, 0644)
    exec.Command("systemctl", "reload", "haproxy").Run()
    
    return ctrl.Result{}, nil
}
```

**Pros:**

- Uses your existing template
- Full control over config format
- Single source of truth

**Cons:**

- More complex scaffolding
- Still requires HAProxy reloads

## Option 3: HAProxy Data Plane API + Dynamic Updates

Install Data Plane API and use runtime server manipulation (no reloads):

```bash
# Install Data Plane API
dpkg -i haproxy-dataplane-api_*.deb

# Configure haproxy with runtime API socket
echo "stats socket /var/run/haproxy.sock mode 600 level admin" >> /etc/haproxy/haproxy.cfg
```

Your controller then uses the API:

```go
// Add backend server dynamically
client.AddServer("backend-name", Server{
    Name:    node.Name,
    Address: nodeIP,
    Port:    nodePort,
})
```

**Pros:**

- Zero-downtime updates
- No config file management
- Most "Kubernetes-native"

**Cons:**

- Requires Data Plane API setup
- More moving parts
- State lives in HAProxy memory

## My Recommendation

**Start with Option 1** - it's the pragmatic choice:

- Matches your current halb architecture
- Simple enough to build in a weekend
- Easy to maintain
- Can migrate to Option 3 later if needed

The key insight: **you don't need IPVS**. You just need something that:

1. Watches K8s Services
2. Allocates VIPs
3. Writes HAProxy config pointing to NodePorts
4. Reloads HAProxy

---

# Q:

vIP Allocations would have to be coordinated with domain admins

# A:

Exactly right - that's a critical on-prem reality check. 
Let me search for how existing solutions handle this coordination:
You're absolutely right - this is where on-prem diverges from cloud. 

The standard pattern is:

## The On-Prem Coordination Model

**One-time coordination (like MetalLB does it):**

1. **Network team allocates a block** - Reserve a range upfront:
   ```
   Network team: "K8s can use 10.50.100.0/24 for LoadBalancer services"
   ```

2. **Configure your controller with that pool**:
   ```yaml
   # ConfigMap or CRD
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: lb-config
     namespace: kube-system
   data:
     ip-pool: "10.50.100.0/24"
   ```

3. **Services auto-allocate from the pool**:
   - Developer creates Service → gets 10.50.100.5 automatically
   - Next service → gets 10.50.100.6
   - Delete service → IP returns to pool

4. **DNS is still manual or via ExternalDNS**

## Three Practical Approaches for Your Situation

### Option A: IP Pool (MetalLB Pattern)

**Best if**: Network team can give you a dedicated /24 or similar

```yaml
# One-time setup
kind: ConfigMap
metadata:
  name: halb-ip-pool
data:
  pools: |
    - name: default
      cidr: 10.50.100.0/24
      autoAssign: true
    - name: dmz
      cidr: 203.0.113.0/28
      autoAssign: false  # Require explicit request
```

**Pros**: True self-service for developers within the pool

**Cons**: Still need DNS automation or manual DNS entries

### Option B: DNS-First (AWS-like)

**Best if**: You control a DNS subdomain but IPs are scarce

```yaml
# Service gets: myapp-abc123.k8s.example.com
# All point to same pool of VIPs (like shared Ingress)
status:
  loadBalancer:
    ingress:
    - hostname: myapp-abc123.k8s.example.com
```

Your controller:

1. Generates unique hostname per service
2. Creates DNS record pointing to one of your halb VIPs
3. Configures HAProxy with host-based routing

**Pros**: 

- Minimal IP consumption (can use just 2-3 VIPs total)
- Automatic DNS

**Cons**: 

- Requires DNS server integration
- Not a "real" LoadBalancer (more like Ingress)
- Doesn't work for non-HTTP protocols

### Option C: Hybrid Ingress Pattern

**Most pragmatic**: Accept that LoadBalancer type isn't right for on-prem

```yaml
# Instead of LoadBalancer, use Ingress + annotations
kind: Ingress
metadata:
  annotations:
    halb.io/vip: "10.50.100.5"  # Optional: request specific IP
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: myapp
            port:
              number: 80
```

**Reality check**: This is what most enterprises actually do - they don't use LoadBalancer type for on-prem, they use Ingress.

## My Recommendation for Your Situation

**Start with Option A (IP pool)** because:

1. **One-time coordination**: Network team gives you 10.50.100.0/24 once
2. **Your controller allocates IPs** automatically from that pool
3. **DNS remains separate** - Use external-dns or document the manual process
4. **Familiar pattern** - Same as MetalLB/kube-vip that teams already know

Then **add Option C (Ingress support)** for HTTP workloads since that's what most apps need anyway.

**Implementation sketch:**
```go
type IPPool struct {
    CIDR      string
    allocated map[string]string // service -> IP
}

func (p *IPPool) Allocate(svcName string) (string, error) {
    // Check if already allocated
    if ip, exists := p.allocated[svcName]; exists {
        return ip, nil
    }
    
    // Find free IP from CIDR
    ip := p.findNextFree()
    p.allocated[svcName] = ip
    
    return ip, nil
}
```

The DNS story is separate - either:

- Manual (document the IPs for DNS team)
- ExternalDNS (automates DNS record creation)
- Your own DNS integration (if you control the zone)
