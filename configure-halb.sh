#!/usr/bin/env bash
#####################################################
# Configure haproxy and keepalived systemd services
#####################################################
[[ "$(id -u)" -ne 0 ]] && {
    echo "⚠  ERR : MUST run as root" >&2

    exit 11
}
type -t haproxy || {
    echo "⚠  ERR : haproxy is NOT INSTALLED" >&2

    exit 22 
}
type -t keepalived || {
    echo "⚠  ERR : keepalived is NOT INSTALLED" >&2

    exit 23
}

systemctl disable --now keepalived
systemctl disable --now haproxy

dir=/usr/lib/systemd/system/keepalived.service.d
mkdir -p $dir
cp keepalived.10-options.conf $dir/10-options.conf
chmod 0644 $dir/10-options.conf
chown -R root:root $dir

dir=/etc/keepalived
cp keepalived.conf $dir/
#cp keepalived-check_apiserver.sh $dir/check_apiserver.sh
chmod 0644 $dir/keepalived.conf
#chmod 0744 $dir/check_apiserver.sh
chown -R root:root $dir

dir=/etc/haproxy
cp haproxy.cfg $dir/
chmod 0644 $dir/haproxy.cfg
chown -R root:root $dir

dir=/usr/lib/systemd/system/haproxy.service.d
mkdir -p $dir
cp haproxy.10-limits.conf $dir/10-limits.conf
chmod 0644 $dir/10-limits.conf
cp haproxy.20-quiet.conf $dir/20-quiet.conf
chmod 0644 $dir/20-quiet.conf
chown -R root:root $dir

#cp etc.hosts /etc/hosts 
#chmod 0644 /etc/hosts

#cp etc.environment /etc/environment
#chmod 0644 /etc/environment

# Configure HALB logging

target=/etc/rsyslog.d/99-haproxy.conf 
cp haproxy-rsyslog.conf $target
chmod 0644 $target
chown root:root $target

# SELinux
setsebool -P haproxy_connect_any 1

# systemd
systemctl daemon-reload
systemctl restart rsyslog.service
systemctl enable --now keepalived
systemctl enable --now haproxy

systemctl is-active haproxy.service || {
    echo "⚠  haproxy.service is NOT active" >&2

    exit 88
}
systemctl is-active keepalived.service || {
    echo "⚠  keepalived.service is NOT active" >&2

    exit 89
}