#!/usr/bin/env bash
#################################################
# Test HALB failover 
#################################################

export HALB_DEVICE=$HALB_DEVICE
export HALB_VIP=$HALB_VIP
export HALB_DOMAIN=$HALB_DOMAIN

info(){ printf "\n\n%s\n" "$@"; }
master(){
    printf "%s.$HALB_DOMAIN\n" $HALB_HOSTS |
    xargs -I{} /bin/bash -c '
        ssh $1 ip -4 addr show dev $HALB_DEVICE |grep -q $HALB_VIP && printf $1
    '  _ {}
}

info "ℹ️  MASTER : $(master)"

# Verify connectivity
test="nc -zvw2 $HALB_VIP $HALB_PORT_K8S $HALB_PORT_STATS https http"
info "🔍  Verify connectivity : $test"
[[ $(type -t nc) ]] && {
    got="$($test 2>&1)" && echo -e "\n$got\n✅  ok" || echo "❌ $got"
} || { printf "🧩  REQUIREs utility: nc"; }


# Verify HA 
info "🔍  Verify LB failover (HA) dynamics : curl -sSIX GET http://$HALB_VIP:$HALB_PORT_STATS/stats"
[[ $(type -t curl) ]] && {
    echo '
      PRESS ENTER when ready to test. 
      
      Use CTRL+C to kill.

      HOW TO:

      1. Find the Keepalived MASTER host. 
         - The LB vIP is attached to its public interface.
      2. Start this test, which spams the LB /stats endpoint.
      3. Stop the systemd haproxy.service on the MASTER host, or reboot it.
         - sudo systemctl stop haproxy.service  # Test host-process failover. 
         - sudo reboot                          # Test host failover.
   
      HTTP 200 responses from LB to these test requests 
      should persist as long as at least one LB host is active.
    '
    read
    seq 999999 |xargs -I{} /bin/bash -c '
        printf "%s : %s\n" "$(date -Is)" "$(curl -sSIX GET http://$0/stats |grep HTTP)"
        sleep 1
    ' "$HALB_VIP:$HALB_PORT_STATS" {} 
} || echo "Use an HTTP client to spam HALB endpoint, http://$HALB_VIP:$HALB_PORT_STATS/stats, to verify failover (HA) when keepalived MASTER node is offline."

exit $?
#######

## Failover should print something like this:

# 2025-12-07T08:48:10-05:00 : HTTP/1.1 200 OK
# 2025-12-07T08:48:11-05:00 : HTTP/1.1 200 OK
# 2025-12-07T08:48:12-05:00 : HTTP/1.1 200 OK
# curl: (7) Failed to connect to 192.168.11.11 port 8404 after 0 ms: Couldn't connect to server
# 2025-12-07T08:48:13-05:00 :
# curl: (7) Failed to connect to 192.168.11.11 port 8404 after 0 ms: Couldn't connect to server
# 2025-12-07T08:48:14-05:00 :
# curl: (7) Failed to connect to 192.168.11.11 port 8404 after 0 ms: Couldn't connect to server
# 2025-12-07T08:48:15-05:00 :
# curl: (7) Failed to connect to 192.168.11.11 port 8404 after 0 ms: Couldn't connect to server
# 2025-12-07T08:48:16-05:00 :
# curl: (7) Failed to connect to 192.168.11.11 port 8404 after 0 ms: Couldn't connect to server
# 2025-12-07T08:48:17-05:00 :
# 2025-12-07T08:48:18-05:00 : HTTP/1.1 200 OK
# 2025-12-07T08:48:19-05:00 : HTTP/1.1 200 OK
# 2025-12-07T08:48:20-05:00 : HTTP/1.1 200 OK