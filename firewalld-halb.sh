#!/usr/bin/env bash
##################################################################
# firewalld : Configure active zone for HALB
# - Idempotent
#
# ARGs: K8S_API_PORT  HALB_STATS_PORT  [ANY(to teardown)]
##################################################################
[[ "$(id -u)" -ne 0 ]] && {
    echo "❌  ERR : MUST run as root" >&2

    exit 11
}
[[ -n $2 ]] || {
    echo "❌  ERR : Missing args" >&2

    exit 22
}
## Assure firewalld.service is running; persist otherwise.
systemctl is-active --quiet firewalld ||
    systemctl enable --now firewalld

k8s_port="$1"
stats_port="$2"
[[ -n $3 ]] &&
    export do='remove' ||
        export do='add'

svc='halb'
zone="$(firewall-cmd --get-active-zone |head -n1)"

[[ $do == 'add' ]] && {
    ## Create and configure the service

    firewall-cmd --get-services --zone=$zone |grep -q "\b$svc\b" ||
        firewall-cmd --new-service=$svc

    at="--permanent --zone=$zone --service=$svc"

    firewall-cmd $at --set-description="HAProxy/Keepalived in VRRP mode"

    firewall-cmd $at --$do-port=80/tcp
    firewall-cmd $at --$do-port=443/tcp
    firewall-cmd $at --$do-port=6443/tcp
    firewall-cmd $at --$do-port=$k8s_port/tcp
    firewall-cmd $at --$do-port=$stats_port/tcp
}
firewall-cmd --permanent --zone=$zone --$do-service=$svc

at="--permanent --zone=$zone"

## Allow ICMP for ping request/reply : Inversion is *required* here when target is DROP 
# firewall-cmd $at --$do-icmp-block-inversion    # Invert so block allows
# firewall-cmd $at --$do-icmp-block=echo-request # block (allow) request 
# firewall-cmd $at --$do-icmp-block=echo-reply   # block (allow) reply

## VRRP : Multicast
firewall-cmd $at --$do-rich-rule='rule family="ipv4" destination address="224.0.0.0/4" accept'

## VRRP : Protocol 112 (an L3 protocol)
# Add DIRECT RULEs for non-UDP/TCP protocols 
# iptables -I INPUT -p 112 -j ACCEPT
# iptables -I OUTPUT -p 112 -j ACCEPT
firewall-cmd --permanent --direct \
    --$do-rule ipv4 filter INPUT 0 -p 112 -j ACCEPT
firewall-cmd --permanent --direct \
    --$do-rule ipv4 filter OUTPUT 0 -p 112 -j ACCEPT

# Update firewalld.service sans restart 
firewall-cmd --reload

firewall-cmd --list-services --zone=$zone |grep -q "\b$svc\b" || {
    echo "❌  ERR : $? : NO service '$svc' is listed in zone '$zone'" >&2

    exit 99
}
