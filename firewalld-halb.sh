#!/usr/bin/env bash
###############################################################################
# firewalld : HALB built of HAProxy and Keepalived (idempotent)
###############################################################################
[[ $(whoami) == 'root' ]] || exit 11

[[ $(systemctl is-active firewalld.service) == 'active' ]] ||
    systemctl enable --now firewalld.service

k8s_port="$1"
stats_port="$2"
svc=halb
zone=$(firewall-cmd --get-active-zone |head -n1)
at="--permanent --zone=$zone --service=$svc"

[[ $(firewall-cmd --get-services |grep $svc) ]] ||
    firewall-cmd --permanent --zone=$zone --new-service=$svc

firewall-cmd $at --set-description="HAProxy/Keepalived in VRRP mode"
firewall-cmd $at --add-port=80/tcp
firewall-cmd $at --add-port=443/tcp
firewall-cmd $at --add-port=6443/tcp
firewall-cmd $at --add-port=$k8s_port/tcp
firewall-cmd $at --add-port=$stats_port/tcp

firewall-cmd --permanent --zone=$zone --add-service=$svc

at="--permanent --zone=$zone"

## Allow ICMP echo-request (via its inversion hellscape)
sudo firewall-cmd $at --add-icmp-block-inversion    # Invert so block allows
sudo firewall-cmd $at --add-icmp-block=echo-request # block (allow) request 
sudo firewall-cmd $at --add-icmp-block=echo-reply   # block (allow) reply

## VRRP : Multicast
firewall-cmd $at --add-rich-rule='rule family="ipv4" destination address="224.0.0.0/4" accept'

## VRRP : Protocol 112 (an L3 protocol)
#firewall-cmd $at --add-rich-rule='rule protocol value="vrrp" accept'
#firewall-cmd $at --add-rich-rule='rule family="ipv4" source address="'$vip'" protocol value="vrrp" accept'
# Add DIRECT RULEs for non-UDP/TCP protocols 
# iptables -I INPUT -p 112 -j ACCEPT
# iptables -I OUTPUT -p 112 -j ACCEPT
firewall-cmd --permanent --direct \
    --add-rule ipv4 filter INPUT 0 -p 112 -j ACCEPT
firewall-cmd --permanent --direct \
    --add-rule ipv4 filter OUTPUT 0 -p 112 -j ACCEPT

## VIP : Allow/Limit traffic to/from VIP address by either IPv4 or IPv6 
#at="--permanent --zone=$zone"
#firewall-cmd $at --add-rich-rule='rule family="ipv4" source address="'$vip'" accept'
#firewall-cmd $at --add-rich-rule='rule family="ipv6" source address="'$vip6'" accept'

# Update firewalld.service sans restart 
firewall-cmd --reload

firewall-cmd --list-all --zone=$zone
