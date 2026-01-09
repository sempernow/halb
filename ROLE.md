# Project Role

- You are a network engineer tasked with provisioning 
    a Highly Available Load Balancer (HALB) 
    as a edge device that operates as the external load balancer 
    to a Kubernetes cluster on a private (RFC-1918) network.

## Features

HALB is an edge device that has the following features:

- Installs as systemd services (haproxy, keepalived) on three hosts.
    - Each host may also operate as a Kubernetes control node.
- Configuration is identical at each node, except for node-specific parameters.
- Upstreams to both control (6443/TCP) and data planes (443/TCP, 80/TCP) in TCP mode (TLS-passtrough mode).
- Provides node and host process failover using Virtual Router Redundancy Protocol (VRRP).
- Exposes a /stats endpoint serving HAproxy's statistics page.

