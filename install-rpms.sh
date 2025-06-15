#!/usr/bin/env bash
######################################
# Install RPMs : K8s deps and tools
######################################
set -euo pipefail

ok(){
    sudo dnf -y install conntrack haproxy keepalived

    # Tools
    all='
    dnf-plugins-core
    selinux-policy-targeted 
    libselinux-utils
    policycoreutils
    setroubleshoot-server
    policycoreutils-python-utils
    gcc 
    make 
    ansible 
    ansible-core 
    iproute-tc 
    bash-completion 
    bind-utils 
    tar 
    nc 
    socat 
    rsync 
    lsof 
    wget 
    curl 
    net-tools 
    tcpdump 
    traceroute 
    nmap 
    arp-scan 
    git 
    httpd 
    httpd-tools 
    jq 
    vim 
    tree 
    htop 
    sysstat 
    fio 
    pciutils
    '
    sudo dnf -y install $all
}
ok || exit $?