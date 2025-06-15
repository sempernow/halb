#!/usr/bin/env bash
#################################################
# Configure the HA LB 
#
# See Makefile recipe : lbconf
#################################################
[[ $(whoami) == 'root' ]] || exit 11

systemctl disable --now keepalived
systemctl disable --now haproxy

dir=/usr/lib/systemd/system/keepalived.service.d
mkdir -p $dir
cp 99-keepalived.conf $dir
chmod 0644 $dir/99-keepalived.conf

dir=/etc/keepalived
cp keepalived.conf $dir/keepalived.conf
cp keepalived-check_apiserver.sh $dir/check_apiserver.sh
chmod 0644 $dir/keepalived.conf
chmod 0744 $dir/check_apiserver.sh
chown root:root -R $dir/

cp haproxy.cfg /etc/haproxy/haproxy.cfg
chmod 0644 /etc/haproxy/haproxy.cfg

#cp etc.hosts /etc/hosts 
#chmod 0644 /etc/hosts

#cp etc.environment /etc/environment
#chmod 0644 /etc/environment

# Configure HALB logging

cp haproxy-rsyslog.conf /etc/rsyslog.d/99-haproxy.conf 
chmod 0644 /etc/rsyslog.d/99-haproxy.conf 

# SELinux
setsebool -P haproxy_connect_any 1

# systemd

systemctl daemon-reload
systemctl restart rsyslog.service
systemctl enable --now keepalived
systemctl enable --now haproxy

#systemctl restart haproxy.service
#systemctl restart keepalived.service

systemctl status haproxy.service |grep Active
systemctl status keepalived.service |grep Active

exit 0
######