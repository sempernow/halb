#!/usr/bin/env bash
#################################################################
# Process the *.tpl files
#################################################################
[[ $HALB_VIP ]] || { 
    echo "⚠  ERR : Environment is NOT CONFIGURED"
    
    exit 11
}
pushd ${BASH_SOURCE%/*}

ipv4(){
    nslookup $1 |grep -A1 $1 |grep Address |grep -v ${HALB_VIP:-__MEH__} |head -n1 |awk '{printf $2}'
}
trim(){
    sed -i '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' $1
    #sed -i '/^[[:space:]]*$/d' $1
}
header(){ echo "## GENERATED $(date -Is) : $PRJ_GIT" @ $(id -un)@$(hostname):${BASH_SOURCE##*/}; }

vip="$HALB_VIP"

lb_1_ipv4=$(ipv4 ${HALB_FQDN_1})
lb_2_ipv4=$(ipv4 ${HALB_FQDN_2})
lb_3_ipv4=$(ipv4 ${HALB_FQDN_3})

[[ $lb_1_ipv4 ]] || { echo '⚠  FAIL @ lb_1_ipv4';exit 21; }
[[ $lb_2_ipv4 ]] || { echo '⚠  FAIL @ lb_2_ipv4';exit 22; }
[[ $lb_3_ipv4 ]] || { echo '⚠  FAIL @ lb_3_ipv4';exit 23; }

## @ haproxy

target='haproxy.cfg'
cat ${target}.tpl \
    |sed "s/LB_1_FQDN[[:space:]]LB_1_IPV4/$HALB_FQDN_1 $lb_1_ipv4/" \
    |sed "s/LB_2_FQDN[[:space:]]LB_2_IPV4/$HALB_FQDN_2 $lb_2_ipv4/" \
    |sed "s/LB_3_FQDN[[:space:]]LB_3_IPV4/$HALB_FQDN_3 $lb_3_ipv4/" \
    |sed "s/LB_DEVICE/$HALB_DEVICE/" \
    |sed "s/STATS_PORT/$HALB_PORT_STATS/" \
    |sed "s/K8S_PORT/$HALB_PORT_K8S/" \
    |sed "s/HTTP_PORT/$HALB_PORT_HTTP/" \
    |sed "s/HTTPS_PORT/$HALB_PORT_HTTPS/" \
    |sed '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' \
    >tmp

cat <(header) tmp >$target 
rm tmp

## @ keepalived

pass="$(cat /dev/urandom |tr -dc [:alnum:] |fold -w8 |head -n1)" 

target='keepalived.conf'
cat ${target}.tpl \
    |sed  "s/SET_DEVICE/$HALB_DEVICE/" \
    |sed "s/SET_PASS/$pass/" \
    |sed "s/SET_VIP/$HALB_VIP/" \
    |sed "s/SET_MASK/$HALB_MASK/" \
    |sed "s/UNICAST_PEER_1/$lb_1_ipv4/" \
    |sed "s/UNICAST_PEER_2/$lb_2_ipv4/" \
    |sed "s/UNICAST_PEER_3/$lb_3_ipv4/" \
    |sed "s/TRACK_DEVICE/$HALB_DEVICE/" \
    |sed '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' \
    >tmp

cat <(header) tmp >$target 
rm tmp

## Keepalived requires a unique configuration file (keepalived-*.conf) 
## at each HAProxy-LB node on which it runs.
## They are identical except for "priority VAL";
## each BACKUP must be unique and lower than that of MASTER.
cat $target \
    |sed "/  $lb_1_ipv4/d" \
    |sed "s/UNICAST_SRC_IP/$lb_1_ipv4/" \
    |sed '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' \
    >tmp

cat <(header) tmp >keepalived-$HALB_FQDN_1.conf 
rm tmp

cat $target \
    |sed "s/state MASTER/state BACKUP/" \
    |sed "s/priority 255/priority 254/" \
    |sed "/  $lb_2_ipv4/d" \
    |sed "s/UNICAST_SRC_IP/$lb_2_ipv4/" \
    |sed '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' \
    >tmp

cat <(header) tmp >keepalived-$HALB_FQDN_2.conf 
rm tmp

cat $target \
    |sed "s/state MASTER/state BACKUP/" \
    |sed "s/priority 255/priority 253/" \
    |sed "/  $lb_3_ipv4/d" \
    |sed "s/UNICAST_SRC_IP/$lb_3_ipv4/" \
    |sed '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' \
    >tmp

cat <(header) tmp >keepalived-$HALB_FQDN_3.conf 
rm tmp

rm $target

## @ etc.hosts <=> /etc/hosts : Append HALB entries

target='etc.hosts'
cat /etc/hosts > $target
tee -a $target <<-EOH
$lb_1_ipv4 $HALB_FQDN_1
$lb_2_ipv4 $HALB_FQDN_2
$lb_3_ipv4 $HALB_FQDN_3
EOH

## @ /etc/environment 

# If has no_proxy param, then reset if not already include HALB addresses
# CIDR to IP Range : https://www.ipaddressguide.com/cidr | https://cidr.xyz/
# E.g., 
# CIDR:        10.11.111.234/27
# First IP:    10.11.111.224
# Last IP:     10.11.111.255
source=/etc/environment
[[ $(cat $source |grep -i no_proxy) ]] && {
    target=etc.environment
    no_proxy="$(cat $source |grep -i no_proxy |cut -d'=' -f2)"
    [[ "${no_proxy/$HALB_FQDN_1/}" == "$no_proxy" ]] && {
        halb_addr_list="
            $HALB_CIDR
            $K8S_SERVICE_CIDR
            $K8S_POD_CIDR
            .$HALB_FQDN_1 
            .$HALB_FQDN_2 
            .$HALB_FQDN_3
        "
        # Append HALB addresses to those already in no_proxy
        for addr in $halb_addr_list;do no_proxy=$no_proxy,$addr;done
    }
    sed  "/no_proxy/d" $source >$target
    echo "no_proxy=$no_proxy" |tee -a $target
}

popd
