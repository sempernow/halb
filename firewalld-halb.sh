#!/usr/bin/env bash
###############################################################################
# firewalld : HALB built of HAProxy and Keepalived (idempotent)
###############################################################################
[[ $(whoami) == 'root' ]] || exit 11

[[ $(systemctl is-active firewalld.service) == 'active' ]] ||
    systemctl enable --now firewalld.service

zone=$(firewall-cmd --get-active-zone |head -n1)

svc=halb
vip="${1}"
vip6="${2}"
vport="${3}"
device="${4}" # Network interface common to all LB nodes

at="--permanent --zone=$zone --service=$svc"

[[ $(firewall-cmd --get-services |grep $svc) ]] ||
    firewall-cmd --permanent --zone=$zone --new-service=$svc

firewall-cmd $at --set-description="HAProxy/Keepalived in VRRP mode"
firewall-cmd $at --add-port=80/tcp
firewall-cmd $at --add-port=443/tcp
firewall-cmd $at --add-port=6443/tcp
firewall-cmd $at --add-port=$vport/tcp

firewall-cmd --permanent --zone=$zone --add-service=$svc

# Add RICH RULEs to zone (cannot be scoped to service)
# (See `man firewalld.richlanguage`)

## VIP : Allow traffic to/from VIP address by either IPv4 or IPv6 
#at="--permanent --zone=$zone"
#echo "Configure firewalld : rich rules @ $at"
#firewall-cmd $at --add-rich-rule='rule family="ipv4" source address="'$vip'" accept'
#firewall-cmd $at --add-rich-rule='rule family="ipv6" source address="'$vip6'" accept'
## VRRP : Multicast
#firewall-cmd $at --add-rich-rule='rule family="ipv4" destination address="224.0.0.0/4" accept' 
## VRRP : Protocol 112
#firewall-cmd $at --add-rich-rule='rule protocol value="vrrp" accept'
#firewall-cmd $at --add-rich-rule='rule family="ipv4" source address="'$vip'" protocol value="vrrp" accept'

# Add DIRECT RULEs (cannot be scoped to zone or service)
## VRRP : Protocol 112
# iptables -I INPUT -p 112 -j ACCEPT
# iptables -I OUTPUT -p 112 -j ACCEPT

firewall-cmd --permanent --direct \
    --add-rule ipv4 filter INPUT 0 -p 112 -j ACCEPT
firewall-cmd --permanent --direct \
    --add-rule ipv4 filter OUTPUT 0 -p 112 -j ACCEPT

# TODO : Add rules to allow Multicast mode (Currently, keeplaived is operating in Unicast mode):
# VRRP Multicast Address: The VRRP specification defines the use of a specific multicast address, 224.0.0.18, for IPv4 VRRP communication (or ff02::12 for IPv6). This address is reserved for VRRP routers, and only routers participating in VRRP join this multicast group. This allows them to efficiently receive advertisements while other devices ignore them.

# Update firewalld.service sans restart 
firewall-cmd --reload

firewall-cmd --list-all --zone=$zone
