#!/usr/bin/env bash
# firewalld (Linux host firewall) get all
[[ "$(id -u)" -ne 0 ]] && {
    echo "❌  ERR : MUST run as root" >&2

    exit 11
}

svc='halb'
zone="$(firewall-cmd --get-active-zone |head -n1)"
ifc="$(firewall-cmd --get-active-zones |grep interfaces |cut -d':' -f2)"
ifc="${ifc#"${ifc%%[![:space:]]*}"}"


[[ "$TERM" ]] && {
    normal=" $( tput sgr0 )"                     # reset
    green="$(  tput setab 2 ; tput setaf 0 ) "   # blk foreground
}

echo -e "\nℹ️  All rules scoped to active zone '$zone' bound to interface '$ifc'"
echo -e "    ${green}WANT${normal}: service:'$svc', rich rule: 'allow' 224.0.0.0/4 (VRRP Multicast)"

firewall-cmd --zone=$zone --list-all

echo -e "\nℹ️  All rules scoped to service '$svc'"
echo -e "    ${green}WANT${normal}: All frontend PORT/PROTO expected by any backend (haproxy.cfg)"

firewall-cmd --info-service=$svc

echo -e "\nℹ️  All rules scoped to interface '$ifc' binding active zone '$zone'"
echo -e "    ${green}WANT${normal}: 'ACCEPT' VRRP protocol ('112' *not* 'vrrp')"

firewall-cmd --direct --get-all-rules

echo
