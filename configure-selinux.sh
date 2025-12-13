#!/usr/bin/env bash
###########################################################
# SELinux : Set to Permissive|Enforcing (now and persist)
# - Idempotent
# ARGs: [Enforcing|Permissive(Default)]
###########################################################
conf=/etc/selinux/config
disabled=$(grep SELINUX=disabled $conf)
permissive=$(grep SELINUX=permissive $conf)
enforcing=$(grep SELINUX=enforcing $conf)

e(){
    [[ $permisive || $disabled ]] || return
    sudo setenforce 1 # set to Enforcing : Unreliable and does NOT persist.
    sudo sed -i -e 's/^SELINUX=disabled/SELINUX=eforcing/' $conf
    sudo sed -i -e 's/^SELINUX=permissive/SELINUX=enforcing/' $conf
}
p(){
    [[ $enforcing || $disabled ]] || return
    sudo setenforce 0 # set to Permissive : Unreliable and does NOT persist.
    sudo sed -i -e 's/^SELINUX=disabled/SELINUX=permissive/' $conf
    sudo sed -i -e 's/^SELINUX=enforcing/SELINUX=permissive/' $conf
}
export -f e
export -f p

was=$(getenforce)
echo $1 |grep -q -i enforc && e || p
now=$(getenforce)

echo "🔍  SELinux : $(getenforce)"
