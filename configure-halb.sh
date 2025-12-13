#!/usr/bin/env bash
############################################################
# Configure halb : haproxy and keepalived systemd services
#
# ARGs: installConfig|updateConfig
############################################################
[[ "$(id -u)" -ne 0 ]] && {
    echo "❌️️  ERR : MUST run as root" >&2

    exit 11
}
type -t haproxy || {
    echo "❌️  ERR : haproxy is NOT INSTALLED" >&2

    exit 22 
}
type -t keepalived || {
    echo "❌️  ERR : keepalived is NOT INSTALLED" >&2

    exit 23
}

#set -a # Export all

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
selinuxPolicyPackage(){

    advisedPPkg(){
        ## SELinux utility audit2allow reports 'Nothing to do', 
        ## else the statement (semodule -i) that would install 
        ## the policy package (*.pp) required to prevent future SELinux denials.
        grep keepalived /var/log/audit/audit.log |
            audit2allow -M keepalived_custom
    }

    echo "🔍  SELinux : Running audit2allow on audit.log of keepalived ..."

    advisedPPkg 2>&1 |grep 'Nothing to do' || {
        ##.Manually install any Policy Package(s) reported by audit2allow. E.g., 
        ## semodule -i keepalived_custom.pp
        ## semodule -i keepalived_haproxy.pp
        echo "🚧  MUST run the advised semodule statement(s) to prevent SELinux denial(s)."
        advisedPPkg
    }
}
etc_configs(){
    ## (Re)Configure halb using local files uploaded earlier.

    ## @ haproxy

    dir=/etc/haproxy
    cp haproxy.cfg $dir/
    chmod 0644 $dir/haproxy.cfg
    chown -R root:root $dir

    ## @ keepalived

    ## SELinux : Fix vrrp_script file location 
    dir=/usr/libexec/keepalived
    install keepalived-check-haproxy.sh $dir/check_haproxy.sh
    semanage fcontext -a -t keepalived_exec_t $dir/check_haproxy.sh
    restorecon -v $dir/check_haproxy.sh

    ## SELinux : Fix keepalived.conf location
    dir=/etc/keepalived
    cp keepalived.conf $dir/
    chmod 0644 $dir/keepalived.conf

    # Set proper context for keepalived files
    #semanage fcontext -a -t keepalived_exec_t /usr/sbin/keepalived
    # restorecon -Rv /etc/keepalived /usr/sbin/keepalived

    # # Allow keepalived to bind to non-standard ports if needed
    # setsebool -P keepalived_connect_any=1
    # # Allow VRRP traffic (if using default VRRP)
    # setsebool -P keepalived_use_nftables=1
    # # or for iptables:
    # setsebool -P keepalived_use_ipsec=0
    # # Allow keepalived to run scripts (for notify/check scripts)
    # setsebool -P keepalived_run_scripts=1
    # # Allow network connectivity for checks
    # setsebool -P keepalived_can_network_connect=1
    # # Allow network binding for services
    # setsebool -P keepalived_can_network_bind=1

    chown -R root:root $dir

    ## If configured for unicast mode, then substitute and verify host's IPv4 address else fail
    grep -q unicast_peer $dir/keepalived.conf && {
        ip="$(ip4)"
        sed -i "s/THIS_IP/$ip/g" $dir/keepalived.conf
        grep -q "$ip" $dir/keepalived.conf ||
            return 44
    }
}
updateConfig(){
    etc_configs 

    systemctl reload haproxy
    systemctl reload keepalived
    systemctl daemon-reload
    #systemctl enable --now keepalived
    
    verify

    sleep 3
    selinuxPolicyPackage 

    return $?
}
installConfig(){
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
	cat <<-EOH >/etc/systemd/journald.conf.d/no-wall.conf
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

    sleep 3
    selinuxPolicyPackage 
}

"$@" || echo "❌️️  ERR at '$BASH_SOURCE' : $?" >&2
