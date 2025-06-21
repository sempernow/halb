#!/usr/bin/env bash
###############################################################################
# firewalld : Allow ICMP only for ping in zone where target is DROP
# - Idempotent
###############################################################################
[[ $(whoami) == 'root' ]] || exit 11

[[ $(systemctl is-active firewalld.service) == 'active' ]] ||
    systemctl enable --now firewalld.service

zone=$(firewall-cmd --get-active-zone |head -n1)
at="--permanent --zone=$zone"

## This does *not* allow ICMP (ping request/reply) if target is DROP.
# firewall-cmd $at --remove-icmp-block-inversion
# firewall-cmd $at --remove-icmp-block=echo-request
# firewall-cmd $at --remove-icmp-block=echo-reply

## Allow ICMP for ping request/reply : Inversion is *required* here when target is DROP 
firewall-cmd $at --add-icmp-block-inversion    # Invert so block allows
firewall-cmd $at --add-icmp-block=echo-request # block (allow) request 
firewall-cmd $at --add-icmp-block=echo-reply   # block (allow) reply

# Update firewalld.service sans restart 
firewall-cmd --reload

firewall-cmd --list-all --zone=$zone
