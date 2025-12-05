#!/usr/bin/env bash
#################################################
# Test HALB failover 
#################################################

# Verify connectivity
test="nc -zvw2 $HALB_VIP $HALB_PORT_K8S $HALB_PORT_STATS https http"
echo "🔍  Verify connectivity : $test"
[[ $(type -t nc) ]] && {
    got="$($test 2>&1)" && echo -e "✅  ok\n$got" || echo "❌ $got"
} || { echo "🧩  REQUIREs utility: nc"; }

echo

# Verify HA 
[[ $(type -t curl) ]] && {
    echo '🧪  Verify LB failover (HA) dynamics.'
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
        curl -ksSIX GET http://$0/stats |grep HTTP
        date -Is;sleep 5
    ' "$HALB_VIP:$HALB_PORT_STATS" {} 
} || echo "Use an HTTP client to spam HALB endpoint, http://$HALB_VIP:$HALB_PORT_STATS/stats, to verify failover (HA) when keepalived MASTER node is offline."

