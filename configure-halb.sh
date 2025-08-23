#!/usr/bin/env bash
#####################################################
# Configure haproxy and keepalived systemd services
#####################################################
update=$1
[[ "$(id -u)" -ne 0 ]] && {
    echo "⚠️️️  ERR : MUST run as root" >&2

    exit 11
}
type -t haproxy || {
    echo "⚠️️  ERR : haproxy is NOT INSTALLED" >&2

    exit 22 
}
type -t keepalived || {
    echo "⚠️️  ERR : keepalived is NOT INSTALLED" >&2

    exit 23
}
verify(){
    for app in haproxy keepalived;do
        systemctl is-active $app.service -q &&
            echo "✅  $app.service ok" >&2 || {
                echo "⚠️️  $app.service is NOT active" >&2

                return 88
            }
    done
}
etc_configs(){

    # Update the confs only

    dir=/etc/keepalived
    cp keepalived.conf $dir/
    chmod 0644 $dir/keepalived.conf
    chown -R root:root $dir

    dir=/etc/haproxy
    cp haproxy.cfg $dir/
    chmod 0644 $dir/haproxy.cfg
    chown -R root:root $dir

    [[ $update ]] && {
        systemctl daemon-reload
        systemctl restart haproxy
        systemctl restart keepalived

        verify
    }
}
[[ $update ]] && {
    etc_configs 

    exit $?
}

## Configure systemd services

systemctl disable --now keepalived
systemctl disable --now haproxy

## Install keepalived cleanup script 
install keepalived-rogue-cleanup.sh /usr/local/bin/

dir=/etc/systemd/system/keepalived.service.d
mkdir -p $dir
cp keepalived.10-options.conf $dir/10-options.conf
chmod 0644 $dir/10-options.conf
chown -R root:root $dir

dir=/etc/systemd/system/haproxy.service.d
mkdir -p $dir
cp haproxy.10-limits.conf $dir/10-limits.conf
chmod 0644 $dir/10-limits.conf
cp haproxy.20-quiet.conf $dir/20-quiet.conf
chmod 0644 $dir/20-quiet.conf
chown -R root:root $dir

## Add a journald drop-in that prevents its default broadcasts to stdout/stderr
## of logs having the highest priorities: 0 (emerg), 1 (alert) or 2 (crit).
mkdir -p /etc/systemd/journald.conf.d
cat <<EOH >/etc/systemd/journald.conf.d/no-wall.conf
[Journal]
ForwardToWall=no
EOH

## Configure HALB logging

target=/etc/rsyslog.d/99-haproxy.conf 
cp haproxy-rsyslog.conf $target
chmod 0644 $target
chown root:root $target

etc_configs 

#cp etc.hosts /etc/hosts 
#chmod 0644 /etc/hosts

#cp etc.environment /etc/environment
#chmod 0644 /etc/environment

setsebool -P haproxy_connect_any 1
systemctl daemon-reload
systemctl daemon-reexec	
systemctl restart rsyslog.service
systemctl restart systemd-journald
systemctl enable --now keepalived
systemctl enable --now haproxy

verify
