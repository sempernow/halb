#!/usr/bin/env bash
############################################################
# Configure halb : haproxy and keepalived systemd services
############################################################
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

ip4(){
    ## Get the IPv4 address of the first-found public interface of this host
    ip --color=never -4 -brief addr "$@" |
        command grep -v -e lo -e docker |
        command grep UP |
        head -n1 |
        awk '{print $3}' |
        cut -d'/' -f1
}
verify(){
    for app in haproxy keepalived;do
        systemctl is-active $app.service -q &&
            echo "✅  $app.service ok" >&2 || {
                echo "⚠️️  $app.service is NOT active" >&2

                return 33
            }
    done
}
etc_configs(){
    ## (Re)Configure halb from PWD files uploaded earlier.
    
    ## @ keepalived.conf

    dir=/etc/keepalived
    cp keepalived.conf $dir/
    chmod 0644 $dir/keepalived.conf
    chown -R root:root $dir

    ## If configured for unicast mode, then substitute and verify host's IPv4 address else fail
    grep -q unicast_peer $dir/keepalived.conf && {
        ip="$(ip4)"
        sed -i "s/THIS_IP/$ip/g" $dir/keepalived.conf
        grep -q "$ip" $dir/keepalived.conf ||
            return 44
    }

    ## @ haproxy.cfg

    dir=/etc/haproxy
    cp haproxy.cfg $dir/
    chmod 0644 $dir/haproxy.cfg
    chown -R root:root $dir

    ##########################################################
    ## Attempts to fix SELinux denials on health check method
    ##########################################################
    # # Restore default contexts
    # sudo restorecon -Rv /etc/keepalived
    # sudo restorecon -Rv /usr/sbin/keepalived

    # # If custom scripts in /etc/keepalived/
    # #sudo chcon -R -t keepalived_script_t /etc/keepalived/*.sh

    # # Allow keepalived scripts to use network
    # sudo setsebool -P keepalived_connect_any=1
    # # Allow multicast (fails if using unicast)
    # #sudo setsebool -P keepalived_use_igmp=1

    # # Correct the PID file context
    # sudo restorecon -v /var/run/keepalived.pid
    # sudo chcon -t keepalived_var_run_t /var/run/keepalived.pid

    # # Ensure the directory has correct context too
    # sudo chcon -t keepalived_var_run_t /var/run/keepalived/

    # ausearch -c 'keepalived' --raw | audit2allow -M keepalived-01
    # semodule -X 300 -i keepalived-01.pp

    # # Create a policy module allowing keepalived to execute systemctl
	# cat > keepalived_systemctl.te <<-'EOF'
	# module keepalived_systemctl 1.0;

	# require {
	# 	type keepalived_t;
	# 	type systemd_systemctl_exec_t;
	# 	class file { read write execute getattr open };
	# }

	# # Allow keepalived to execute systemctl
	# allow keepalived_t systemd_systemctl_exec_t:file { read write execute getattr open };
	# EOF

    # # Compile and install
    # sudo checkmodule -M -m -o keepalived_systemctl.mod keepalived_systemctl.te
    # sudo semodule_package -o keepalived_systemctl.pp -m keepalived_systemctl.mod
    # sudo semodule -i keepalived_systemctl.pp

}

[[ $update ]] && {
    systemctl disable --now keepalived
    sleep 3
  
    etc_configs 

    systemctl daemon-reload
    systemctl restart haproxy
    systemctl enable --now keepalived
    verify

    exit $?
}

## Configure systemd services

systemctl disable --now keepalived
systemctl disable --now haproxy
sleep 3 # Allow keepalived to delete vIP from network interface
ip -4 -brief addr # See that it has

## Install keepalived cleanup script 
## - Called by /etc/systemd/system/keepalived.service.d/10-options.conf
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

## Configure halb (haproxy.cfg, keepalived.conf)
etc_configs 

#cp etc.hosts /etc/hosts 
#chmod 0644 /etc/hosts

#cp etc.environment /etc/environment
#chmod 0644 /etc/environment

setsebool -P haproxy_connect_any 1
systemctl daemon-reload
systemctl daemon-reexec	
sleep 3
systemctl restart rsyslog.service
systemctl restart systemd-journald
sleep 3
systemctl enable --now haproxy
sleep 3
systemctl enable --now keepalived

verify

