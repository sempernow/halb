#!/usr/bin/env bash
#################################################
# Test HALB failover 
#################################################

# @ nc : Verify connectivity
test="nc -zvw2 $HALB_VIP $HALB_PORT_K8S $HALB_PORT_STATS https http"
echo "🔍  Verify connectivity : $test"
[[ $(type -t nc) ]] && {
    got="$($test 2>&1)" && echo -e "✅  ok\n$got" || echo "❌ $got"
} || { echo "🧩  REQUIREs utility: nc"; }

# @ ping : Verify HA (failover) dynamics
[[ $(type -t ping) ]] && {
    echo '
        Verify FAILOVER (HA) dynamics"
        
        While this ping test is running, reboot
        or shutdown the Keepalive MASTER host. 👈

        Connectivity should persist as long as 
        at least one HALB host is running.

        PRESS ENTER when ready to test. 

        Use CTRL+C to kill.
    '
    read
    ping -4 -D $HALB_VIP
} || echo "Use \`ping -4 -D $HALB_VIP\` to verify failover (HA) when keepalived MASTER node is offline."
