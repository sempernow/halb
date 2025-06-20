## /etc/keepalived/keepalived.conf
## See : man keepalived.conf
## SET MODE to 0644 if user is root
## https://kubesphere.io/docs/v3.4/installing-on-linux/high-availability-configurations/set-up-ha-cluster-using-keepalived-haproxy/
## https://chatgpt.com/c/67885634-b7cc-8009-b2fb-3343dadebaaf

global_defs {
    router_id K8S1
    max_auto_priority
    default_interface SET_DEVICE
    #vrrp_garp_interval 0
    #vrrp_gna_interval 0
    enable_script_security
    ## Enable vrrp_skip_check_adv_addr only if VRRP adverts 
    ## are rejected due to mismatched source IPs. (See kubesphere.io)
    #vrrp_skip_check_adv_addr 
}

vrrp_script check_haproxy {
    user root
    # env { 
    #     VIP="SET_VIP"
    #     PORT="SET_PORT"
    # }
    ## Check if HAProxy is running
    script "/usr/bin/pgrep haproxy"
    # SELinux denies:
    #script "/usr/bin/systemctl is-active --quiet haproxy"
    interval 2  # Check every 2 seconds
    fall 3      # Mark the service as failed after 3 failures
    rise 2      # Mark the service as up after 2 successes
    #weight -10  # Reduce priority by 10 if the script fails
}

vrrp_instance VI_1 {
    state MASTER
    interface SET_DEVICE
    virtual_router_id 151
    priority 255
    advert_int 1
    #promote_secondaries
    
    authentication {
        auth_type PASS
        auth_pass SET_PASS
    }
    
    ## Use subnet-CIDR mask : See: ip -brief -4 addr
    virtual_ipaddress {
        SET_VIP/SET_MASK
    }
    # ## Unicast instead of default Multicast
    # unicast_src_ip THIS_IP
    # unicast_peer {
    #     UNICAST_PEER_1    
    #     UNICAST_PEER_2    
    #     UNICAST_PEER_3    
    # }
    
    track_script {
        check_haproxy
    }
}
