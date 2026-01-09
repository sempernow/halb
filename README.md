# HALB :  **HA** Network **L**oad **B**alancer built of HAProxy / Keepalived

Provision a multi-node, L4 (TCP mode) __load balancer__
that implements Virtual Router Redundancy Protocol (VRRP)
to handle N-seconds failover on process or host failure,
for use as an op-prem __edge__ device to a __Kubernetes__ cluster.

## Features

| Feature | Description |
|---------|-------------|
| HAProxy TCP mode (TLS passthrough) | Configured for all frontends; terminates nothing, preserving end-to-end encryption |
| 3-node cluster with VRRP | Unicast peer communication for reliable failover in any network environment |
| SELinux support | Comprehensive policy with `semanage`, `restorecon`, and automatic policy package generation |
| Health checks | `tcp-check` enabled on all backends with configurable intervals |
| Stats endpoint | HAProxy statistics page exposed on `:8404/stats` |
| Firewall rules | Protocol 112 (VRRP), multicast, and all service ports pre-configured via firewalld |
| systemd integration | Drop-ins for resource limits, quiet operation, and cleanup scripts |

## PROXY Protocol Requirement

HALB uses HAProxy's `send-proxy` directive on HTTP/HTTPS ingress backends (ports 80 and 443).
This sends a [PROXY protocol](https://www.haproxy.org/download/1.8/doc/proxy-protocol.txt) header
to preserve the original client IP address through the load balancer.

**The upstream ingress controller must be configured to accept PROXY protocol** on NodePorts 30080 and 30443,
otherwise connections will fail with protocol errors.

### Ingress NGINX Configuration

Add the following to the ingress controller's ConfigMap:

```yaml
data:
  use-proxy-protocol: "true"
```

Or via Helm values:

```yaml
controller:
  config:
    use-proxy-protocol: "true"
```

### Disabling PROXY Protocol

If your ingress controller does not support PROXY protocol, remove `send-proxy` from the
backend server lines in `haproxy.cfg.tpl`:

```diff
- server      UPSTREAM_FQDN_1 UPSTREAM_IP_1:30080 send-proxy
+ server      UPSTREAM_FQDN_1 UPSTREAM_IP_1:30080
```

Note: Without PROXY protocol, the ingress controller will see HALB's IP as the client source IP
rather than the actual client.

## __vIP__ for VRRP @ AD DNS

- Add DHCP reservation 
    - Declare a *dummy MAC* for the vIP using prefix "`02`", which designates it as __locally administered__.
        - __`02:00:00:00:01:01`__
- Pick an available IP within the network's hosts-address range yet outside the DHCP range:
    - `192.168.11.11` (__vIP__)
- Add *two* DNS apex (__`A`__) records, both resolving to the cluster's vIP:
    - FQDN: __`kube.lime.lan`__ 
        - Production cluster (presented to customers).
    - FQDN: __`k8s1.lime.lan`__
        - Internal usage only.

This scheme provides stable DNS for all clusters;  
prod (`kube`), dev (`k8s1`, `k8s2`, &hellip;), test &hellip;.  
Prod cutover is acheived simply by changing the vIP of prod's apex record.


## `default-server` block:

```ini
default 
    ...
    default-server check inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
```

__Settings : Field-by-field Breakdown__:

| Directive     | Meaning                                                      | Suitability for K8s |
|---------------|--------------------------------------------------------------|----------------------|
| `check`       | Enables health checks for backend servers                    | ✅ Required           |
| `inter 10s`   | Send health checks every 10 seconds while server is UP       | ✅ Conservative       |
| `downinter 5s`| Check every 5s when the server is DOWN (faster recovery)     | ✅ Good               |
| `rise 2`      | Mark server UP after 2 consecutive successful checks         | ✅ Reasonable         |
| `fall 2`      | Mark server DOWN after 2 consecutive failed checks           | ✅ Fast failover      |
| `slowstart 60s` | When a server recovers, ramp up traffic gradually over 60s | ✅ Recommended for API servers or ingress endpoints that need warm-up time |
| `maxconn 250` | Limit max concurrent connections to this host                | ⚠️️️️️ Fine if servers aren't under high pressure, but maybe raise for large clusters |
| `maxqueue 256`| If `maxconn` is reached, queue up to 256 connections         | ✅ Good               |
| `weight 100`  | Default load balancing weight                                | ✅ Standard           |

---

### 🧠 Suitability for:

#### ✅ **Kubernetes Control Plane (API servers):**
- ✅ `slowstart` helps avoid thundering herd during rejoin
- ✅ Fast failover (`fall 2`) and moderate rejoin (`rise 2`)
- ✅ Conservative check intervals to avoid flapping

#### ✅ **Kubernetes Data Plane (Ingress/Service TCPs):**
- Same logic applies
- May want lower `inter` values (e.g., `inter 5s`) if you want faster detection of failure
- May want higher `maxconn` (e.g., 1000) depending on expected load

---

## 🚀 Optional Tuning Ideas (Based on Use Case)

| Scenario                        | Suggested Change                                      |
|---------------------------------|-------------------------------------------------------|
| High traffic data plane         | `maxconn 1000` or higher                              |
| Sensitive control plane failover| `inter 5s` and `fall 1` for ultra-fast detection      |
| Faster rejoin                   | `rise 1` (only 1 good check to mark UP again)         |
| Remove queues completely        | Remove `maxqueue` (default: no queuing)              |

---

