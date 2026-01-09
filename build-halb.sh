#!/usr/bin/env bash
#################################################################
# Process the *.tpl files
#################################################################
[[ $HALB_VIP ]] || { 
    echo "⚠️  ERR : Environment is NOT CONFIGURED"
    
    exit 11
}
pushd ${BASH_SOURCE%/*}

ipv4(){ nslookup $1 |grep -A1 $1 |grep Address |grep -v ${HALB_VIP:-DNF} |head -n1 |awk '{printf $2}'; }
header(){ echo "## GENERATED $(date -Is) : $PRJ_GIT" @ $(id -un)@$(hostname):${BASH_SOURCE##*/}; }

vip="$HALB_VIP"

UPSTREAM_IP_1="$(ipv4 $HALB_UPSTREAM_1)"
UPSTREAM_IP_2="$(ipv4 $HALB_UPSTREAM_2)"
UPSTREAM_IP_3="$(ipv4 $HALB_UPSTREAM_3)"

[[ $UPSTREAM_IP_1 ]] || { echo '⚠️  FAIL @ UPSTREAM_IP_1';exit 21; }
[[ $UPSTREAM_IP_2 ]] || { echo '⚠️  FAIL @ UPSTREAM_IP_2';exit 22; }
[[ $UPSTREAM_IP_3 ]] || { echo '⚠️  FAIL @ UPSTREAM_IP_3';exit 23; }

HALB_IP_1="$(ipv4 $HALB_FQDN_1)"
HALB_IP_2="$(ipv4 $HALB_FQDN_2)"
HALB_IP_3="$(ipv4 $HALB_FQDN_3)"

[[ $HALB_IP_1 ]] || { echo '⚠️  FAIL @ HALB_IP_1';exit 24; }
[[ $HALB_IP_2 ]] || { echo '⚠️  FAIL @ HALB_IP_2';exit 25; }
[[ $HALB_IP_3 ]] || { echo '⚠️  FAIL @ HALB_IP_3';exit 26; }

## @ haproxy

target='haproxy.cfg'
cat ${target}.tpl |
    sed "s/UPSTREAM_FQDN_1[[:space:]]UPSTREAM_IP_1/$HALB_UPSTREAM_1 $UPSTREAM_IP_1/" |
    sed "s/UPSTREAM_FQDN_2[[:space:]]UPSTREAM_IP_2/$HALB_UPSTREAM_2 $UPSTREAM_IP_2/" |
    sed "s/UPSTREAM_FQDN_3[[:space:]]UPSTREAM_IP_3/$HALB_UPSTREAM_3 $UPSTREAM_IP_3/" |
    sed "s/HALB_DEVICE/$HALB_DEVICE/" |
    sed "s/STATS_PORT/$HALB_PORT_STATS/" |
    sed "s/K8S_PORT/$HALB_PORT_K8S/" |
    sed "s/HTTP_PORT/$HALB_PORT_HTTP/" |
    sed "s/HTTPS_PORT/$HALB_PORT_HTTPS/" |
    sed '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' >tmp

cat <(header) tmp >$target 
rm tmp

## @ keepalived

pass="$(cat /dev/urandom |tr -dc [:alnum:] |fold -w8 |head -n1)" 

target='keepalived.conf'
cat ${target}.tpl |
    sed  "s/SET_DEVICE/$HALB_DEVICE/" |
    sed "s/SET_PASS/$pass/" |
    sed "s/SET_VIP/$HALB_VIP/" |
    sed "s/SET_MASK/$HALB_MASK/" |
    sed "s/UNICAST_PEER_1/$HALB_IP_1/" |
    sed "s/UNICAST_PEER_2/$HALB_IP_2/" |
    sed "s/UNICAST_PEER_3/$HALB_IP_3/" |
    sed "s/TRACK_DEVICE/$HALB_DEVICE/" |
    sed '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' >tmp

cat <(header) tmp >$target 
rm tmp

## Keepalived requires a unique configuration file (keepalived-*.conf) 
## at each HAProxy-LB node on which it runs.
## They are identical except for "priority VAL";
## each BACKUP must be unique and lower than that of MASTER.
cat $target |
    sed "/  $HALB_IP_1/d" |
    sed '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' >tmp
cat <(header) tmp >keepalived-$HALB_FQDN_1.conf 
rm tmp

cat $target |
    sed "/  $HALB_IP_2/d" |
    sed "s/state MASTER/state BACKUP/" |
    sed "s/priority 255/priority 254/" |
    sed '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' >tmp
cat <(header) tmp >keepalived-$HALB_FQDN_2.conf 
rm tmp

cat $target |
    sed "/  $HALB_IP_3/d" |
    sed "s/state MASTER/state BACKUP/" |
    sed "s/priority 255/priority 254/" |
    sed '/^[[:space:]]*#/d; s/[[:space:]]+#.*$//' >tmp
cat <(header) tmp >keepalived-$HALB_FQDN_3.conf 
rm tmp

rm $target

## @ etc.hosts <=> /etc/hosts 
## Append HALB entries for local DNS resolution
target='etc.hosts'
cat /etc/hosts > $target
tee -a $target <<-EOH
$HALB_IP_1 $HALB_FQDN_1
$HALB_IP_2 $HALB_FQDN_2
$HALB_IP_3 $HALB_FQDN_3
EOH

## @ /etc/environment 
## If has no_proxy param, then reset if not already include HALB addresses
## CIDR to IP Range : https://www.ipaddressguide.com/cidr | https://cidr.xyz/
## E.g., 
## CIDR:        10.11.111.234/27
## First IP:    10.11.111.224
## Last IP:     10.11.111.255
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
