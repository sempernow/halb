#!/usr/bin/env bash

[[ $(whoami) == 'root' ]] || exit 11

VIPs=($1) # space-delimited (array) elements
MASK="$2"
INTERFACE="$3"


echo "ℹ️ Disabling keepalived and haproxy"
systemctl disable --now keepalived
systemctl disable --now haproxy

echo "ℹ️ Killing any rogue processes"
echo "[INFO] Removing any assigned VIPs..."
pkill -9 keepalived
pkill -9 haproxy

echo "ℹ️ Removing any assigned VIPs..."
for vip in "${VIPs[@]}"; do
    command ip -4 -brief addr show dev "$INTERFACE" |grep $vip && {
        echo "🛠️  Removing VIP '$vip/$MASK' from '$INTERFACE'"
        ip addr del "$vip/$MASK" dev "$INTERFACE" || {
            echo "❌  ERR : $?"
            ip -4 -brief addr
            exit 99
        }
    }
done

echo "ℹ️ Deleting all local configuration files"
rm -f *halb.sh haproxy* keepalived*

# echo "ℹ️ Removing Keepalived and HAProxy configs..."
# rm -f /etc/keepalived/keepalived.conf
# rm -f /etc/haproxy/haproxy.cfg

# echo "ℹ️ Optionally uninstall packages (y/n)?"
# read -r UNINSTALL
# if [[ "$UNINSTALL" == "y" ]]; then
#     dnf remove -y keepalived haproxy
# fi

echo "✅ Teardown complete."
ip -4 -brief addr show dev "$INTERFACE"