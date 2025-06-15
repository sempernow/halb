# Q:

What would cause VRRP packets between nodes to be dropped on RHEL8 if has:

```bash
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p vrrp -j ACCEPT
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -p vrrp -j ACCEPT
```

# A:

VRRP (protocol 112) isn’t a "normal" TCP/UDP flow—it’s an IPv4‐level protocol that uses multicast (`224.0.0.18`) and a hop-limit of 255. Even if you’ve added direct iptables rules to `ACCEPT` "`‐p vrrp`", there are a few common reasons why the Linux host would still drop (or ignore) VRRP advertisements:

## 1. **Reverse-Path Filtering (`rp_filter`) Dropping Multicast**
By default, RHEL8 enables __strict reverse-path filtering__ on every interface. When a VRRP packet arrives on an interface, the kernel checks "Can I route *back* to the source IP via this same interface?" If the answer is "no," the packet is silently discarded—even before it ever hits netfilter. Since VRRP advertisements come from another router’s "virtual" IP (often outside the node’s unicast routing table), `rp_filter` will typically drop them.
To verify/disable `rp_filter`:

## 1. foo

```bash
ifname=ens33

# Check current setting on each interface
sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.$ifname.rp_filter

# Disable (or put into loose mode) for all interfaces:
sudo sysctl -w net.ipv4.conf.all.rp_filter=0
sudo sysctl -w net.ipv4.conf.default.rp_filter=0

# Persist via /etc/sysctl.d/99-disable-rpfilter.conf:
# net.ipv4.conf.all.rp_filter = 0
# net.ipv4.conf.default.rp_filter = 0
```

Once you turn off strict reverse-path filtering (or set it to "loose" by using value 1), the kernel will stop dropping those multicast VRRP packets.

## 2. **Protocol-112 Matching vs. "‐p vrrp"**
Although iptables supports protocol aliases, in practice "`-p vrrp`" __doesn’t always translate cleanly__ under firewalld’s nftables backend. Internally, VRRP is IPv4 protocol 112. If your direct rule was interpreted incorrectly (or inserted into the wrong chain), the flood of VRRP frames could still get rejected. Double-check that your direct rule truly maps to "protocol 112" by listing the raw nftables/iptables rules:

```bash
# After reloading firewalld, show the raw nftables ruleset:
sudo firewall-cmd --reload
sudo nft list ruleset | grep vrrp -A3

# Or for legacy iptables-nft view:
sudo iptables -t filter -L INPUT -v -n | grep 112
sudo iptables -t filter -L OUTPUT -v -n | grep 112
```

If you don’t see a rule matching ip proto 112 in INPUT/OUTPUT, then "`‐p vrrp`" wasn’t translated. In that case, __explicitly add by number__:

```bash
sudo firewall-cmd --permanent --direct \
    --add-rule ipv4 filter INPUT 0 -p 112 -j ACCEPT
sudo firewall-cmd --permanent --direct \
    --add-rule ipv4 filter OUTPUT 0 -p 112 -j ACCEPT
sudo firewall-cmd --reload
```

## 3. **Firewalld Zone Priorities / Missing Zone Binding**
Even with a direct rule, firewalld’s default policy for the interface’s zone may "reject" or "drop" IPv4 multicast before your direct rule ever sees it. In RHEL8, direct-inserted rules go into the first evaluation stage—**but** if your interface is bound to a zone that has a more specific "drop all non-zone-services" policy, multicasts may be filtered out higher up. To confirm:

```bash
z=k8s

# See which zone your interface is in
firewall-cmd --get-active-zones
# Look at that zone’s services/multicast policy
firewall-cmd --zone=$z --list-all
```

If the active zone has something like `policy=drop` or explicitly `disable-multicast=yes`, __VRRP will be dropped regardless__ of your direct rule. Either switch the interface to a zone that allows multicast or add a "rich-rule" instead of a direct rule:

```bash
sudo firewall-cmd --permanent \
    --zone=$z --add-rich-rule='rule family="ipv4" \
    protocol value="112" accept'
sudo firewall-cmd --reload
```

## 4. **Kernel Multicast / Interface-Level Settings**
VRRP uses a __link-local multicast address__ (`224.0.0.18`). If multicast is turned off at the interface or `sysctl` level, you won’t see any VRRP frames. Check that multicast isn’t disabled:

```bash
ifname=ens33

# Ensure the interface is set to receive multicast
ip link show dev $ifname
# Look for "MULTICAST" in the flags list. If it’s missing:
sudo ip link set dev $ifname multicast on

# Also check sysctl for IGMP snooping / multicast route handling
sysctl net.ipv4.conf.all.mc_forwarding
sysctl net.ipv4.conf.$ifname.mc_forwarding
```

If an upstream switch or bridge has IGMP snooping disabled/misconfigured, VRRP may not reach the peers. But on a "flat" Ethernet segment, simply ensuring the NIC has MULTICAST enabled is usually enough.

## 5. **SELinux Context for Keepalived / vrrpd Daemon (Less Common)**
In RHEL8, if you’re running keepalived or another VRRP-daemon under an unexpected SELinux domain (e.g. `unconfined_t` instead of `keepalived_t`), the kernel’s multicast sockets for protocol 112 might be blocked by SELinux. You can verify AVC denials by looking at `/var/log/audit/audit.log` or running `ausearch -m avc`. If you see something like:

```
avc:  denied  { create_socket } for  pid=1234 comm="keepalived" \
    scontext=system_u:system_r:unconfined_t:s0 tcontext=system_u:object_r:kernel_t:s0 \
    tclass=rawip_socket
```

then SELinux is preventing keepalived from opening a VRRP socket. The fix is to run keepalived in its proper SELinux domain (`keepalived_t`) or adjust a local policy (e.g. `audit2allow`) to permit raw-ip sockets.

---

### __Checklist to Troubleshoot__ in RHEL 8

## 1. **Verify `rp_filter`**

```bash
sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.default.rp_filter
# If any =1, set them to 0 or 2 (loose) temporarily
sudo sysctl -w net.ipv4.conf.all.rp_filter=0
sudo sysctl -w net.ipv4.conf.default.rp_filter=0
```

## 2. **Ensure Direct Rules Really Allow Protocol 112**

```bash
# Remove "vrrp" alias if present, add numeric proto
sudo firewall-cmd --permanent --direct \
    --remove-rule ipv4 filter INPUT 0 -p vrrp -j ACCEPT
sudo firewall-cmd --permanent --direct \
    --remove-rule ipv4 filter OUTPUT 0 -p vrrp -j ACCEPT

sudo firewall-cmd --permanent --direct \
    --add-rule ipv4 filter INPUT 0 -p 112 -j ACCEPT
sudo firewall-cmd --permanent --direct \
    --add-rule ipv4 filter OUTPUT 0 -p 112 -j ACCEPT
sudo firewall-cmd --reload

# Confirm the rule shows up:
sudo nft list ruleset | grep 112
```

## 3. **Check Zone Multicast Policy**

```bash
# Which zone is the ensX (or ethX) interface in?
sudo firewall-cmd --get-active-zones
# View that zone’s settings—look for "disable-multicast"
sudo firewall-cmd --zone=public --list-all
# If it’s blocking multicast, either:
#  a) move ensX to a zone that allows multicast:
sudo firewall-cmd --zone=trusted --change-interface=ensX
#  b) Add a rich rule instead:
sudo firewall-cmd --permanent --zone=public \
    --add-rich-rule='rule family="ipv4" protocol value="112" accept'
sudo firewall-cmd --reload
```

## 4. **Verify Multicast & NIC Settings**

```bash
ip link show dev ensX  # Should contain "MULTICAST"
sudo ip link set dev ensX multicast on
# If you’re behind a linux bridge, confirm the bridge has multicast enabled:
bridge link show dev br0   # look for MULTICAST there too
```

## 5. **Check for SELinux AVC Denials**

```bash
ausearch -m avc -ts recent
# Or look in /var/log/audit/audit.log for "keepalived" or "vrrpd"
# If you see rawip_socket denials, label keepalived to keepalived_t or allow via audit2allow:
sudo semodule -i my_vrrp_rawip.te   # (generated via audit2allow)
```

---

**TL;DR:**
Even though you added direct firewall rules to allow "`-p vrrp`", 
Linux will still drop VRRP packets if:

* **`rp_filter`** is on (strict), so multicast VRRP fails reverse-path check.
* The direct rule never translated to "proto 112" in the actual nftables ruleset.
* The firewalld zone bound to your interface explicitly blocks IPv4 multicasts.
* The NIC or bridge is not in MULTICAST mode.
* SELinux is preventing keepalived (or your VRRP daemon) from opening a raw-IP socket.

Once you disable/loosen `rp_filter`, confirm the rule is indeed `-p 112 -j ACCEPT` in nftables, and allow IPv4 multicast in your zone/interface, VRRP packets will be received correctly.
