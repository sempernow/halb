#------------------------------------------------------------------------------
# /etc/haproxy/haproxy.cfg
#
# This configures HAProxy as a Highly Available Load Balancer (HALB) 
# to run on each K8s node as a reverse proxy in TCP mode, utilizing VRRP.
# HAProxy monitors backend servers (TLS handshake check), 
# curating its LB list (pool) of those upstreams accordingly.
# Node failover (HA) is provided externally by Keepalived.
# 
# Documentation : http://www.haproxy.org/download/2.9/doc/
#
# VALIDATE the configuration: 
#
#   haproxy -c -f /etc/haproxy/haproxy.cfg 
#
# Configure rsyslog @ /etc/rsyslog.d/99-haproxy.conf
# (Source: haproxy-rsyslog.conf)
#
# See logs:
#   sudo cat /var/log/haproxy.log       # rsyslog.service
#   sudo journalctl -u rsyslog          # journald.service
#   sudo journalctl -u haproxy.service  # journald.service
#------------------------------------------------------------------------------

global

    # Log levels : info|warning
    log         /dev/log local0 info  
 
    user        haproxy
    group       haproxy
    
    daemon
    #quiet
    #pidfile /var/run/haproxy.pid
    ## maxconn : Maximum concurrent connections across all frontends, else queued, else dropped. 
    ## Set per ulimit (FDs; 1 FD/conn; RHEL default is 1024), mem (10KB/conn) and overrides (/etc/security/limits.conf)
    ## Example: 4 GB = 4 * 1024 * 1024 KB = 4,194,304 KB
    ##          Max conns < 4,194,304 KB / 10 KB (~419,000, so not the limiter)
    ##          Max conns < 0.8 $(ulimit -n) (~5200)
    ##          - See systemd : /haproxy.service.d/10-limits.conf
    ## maxconn is also allowed in other contexts: defaults, defaults/default-server, frontend, and backend/server.
    maxconn     4000

## Layer 4 (TCP) mode
defaults
    log             global
    option          tcplog
    option          dontlognull
    #option          log-health-checks
    retries         2
    timeout         connect          5s
    #timeout         queue           50s
    timeout         client          50s
    timeout         server          50s
    #timeout         http-request    10s
    #timeout         http-keep-alive 10s
    timeout         check           10s
    mode            tcp
    default-server  check inter 5s downinter 5s rise 1 fall 1 slowstart 60s maxconn 250 maxqueue 256 weight 100

listen stats
    bind *:STATS_PORT
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats show-node
    #stats auth admin:stats

## Frontend for K8s API Server
frontend k8s_api_front
    #bind                *:K8S_PORT interface LB_DEVICE
    bind                *:K8S_PORT
    default_backend     k8s_api_back

## Backend for K8s API Server
backend k8s_api_back

    # Verify TLS handshake
    #option      ssl-hello-chk
    # Verify TCP handshake
    option      tcp-check

    tcp-check   connect
    #balance     leastconn
    balance     roundrobin
    server      LB_1_FQDN LB_1_IPV4:6443
    server      LB_2_FQDN LB_2_IPV4:6443 
    server      LB_3_FQDN LB_3_IPV4:6443 

## Frontend for K8s Ingress by HTTP
frontend k8s_ingress_http_front

    bind                *:80
    default_backend     k8s_ingress_http_back
    
## Backend for K8s Ingress by HTTP
backend k8s_ingress_http_back

    # Verify TLS handshake
    #option      ssl-hello-chk
    # Verify TCP handshake
    option      tcp-check
    tcp-check   connect

    #balance     leastconn
    balance     roundrobin
    # @ send-proxy (mode: tcp or http) : Adds header: 
    # PROXY TCP4 <client-ip> <vip> <ephemeral-port> <frontend-port>
    server      LB_1_FQDN LB_1_IPV4:HTTP_PORT send-proxy
    server      LB_2_FQDN LB_2_IPV4:HTTP_PORT send-proxy
    server      LB_3_FQDN LB_3_IPV4:HTTP_PORT send-proxy

## Frontend for K8s Ingress HTTPS
frontend k8s_ingress_https_front

    bind                *:443
    default_backend     k8s_ingress_https_back
    
## Backend for K8s Ingress HTTPS
backend k8s_ingress_https_back

    # Verify TLS handshake
    #option      ssl-hello-chk
    # Verify TCP handshake
    option      tcp-check
    tcp-check   connect

    #balance     leastconn
    balance     roundrobin
    server      LB_1_FQDN LB_1_IPV4:HTTPS_PORT send-proxy
    server      LB_2_FQDN LB_2_IPV4:HTTPS_PORT send-proxy
    server      LB_3_FQDN LB_3_IPV4:HTTPS_PORT send-proxy

## Frontend for other Ingress or Service.type: LoadBalancer HTTPS
# frontend other_svc_front
#
#     bind                *:OTHER_TLS
#     default_backend     other_svc_back
    
## Backend for other Ingress or Service.type: LoadBalancer HTTPS
# backend other_svc_back
#
#     option      ssl-hello-chk
#     #balance     roundrobin
#     ## Session stickyness : use at NodePorts, LoadBalancer Services, and Stateful Apps.    
#     balance source   # 👈 Source IP based load balancing for session stickyness
#     server      LB_1_FQDN LB_1_IPV4:HTTPS_PORT send-proxy
#     server      LB_2_FQDN LB_2_IPV4:HTTPS_PORT send-proxy
#     server      LB_3_FQDN LB_3_IPV4:HTTPS_PORT send-proxy
