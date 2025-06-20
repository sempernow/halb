#!/usr/bin/env bash

[[ $(whoami) == 'root' ]] || exit 11

VIPs=($1) # space-delimited (array) elements
MASK="$2"
INTERFACE="$3"
#UNINSTALL="$4"

echo "[INFO] Stopping services..."
systemctl stop keepalived
systemctl stop haproxy

echo "[INFO] Disabling services..."
systemctl disable keepalived || true
systemctl disable haproxy || true

echo "[INFO] Killing any rogue processes ..."

pkill -9 keepalived
pkill -9 haproxy

echo "[INFO] Removing any assigned VIPs..."

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

rm -f *halb.sh haproxy* keepalived*

# echo "[INFO] Removing Keepalived and HAProxy configs..."
# rm -f /etc/keepalived/keepalived.conf
# rm -f /etc/haproxy/haproxy.cfg

# echo "[INFO] Optionally uninstall packages (y/n)?"
# read -r UNINSTALL
# if [[ "$UNINSTALL" == "y" ]]; then
#     dnf remove -y keepalived haproxy
# fi

echo "[INFO] Teardown complete."
echo "✅"
ip -4 -brief addr show dev "$INTERFACE"