#!/usr/bin/env bash
# firewalld (Linux host firewall) get all
[[ "$(id -u)" -ne 0 ]] && {
    echo "❌  ERR : MUST run as root" >&2

    exit 11
}
firewall-cmd --zone=k8s-external --list-all
firewall-cmd --info-service=halb

echo -e "\nℹ️  Direct rules : Scoped to interface"
firewall-cmd --direct --get-all-rules
echo 
