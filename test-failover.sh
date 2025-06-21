#!/usr/bin/env bash
#################################################
# Test HALB failover 
#################################################

# @ nc : Verify connectivity
echo 'Verify connectivity : nc -zv $HALB_VIP $HALB_PORT_K8S'
[[ $(type -t nc) ]] && nc -zv $HALB_VIP $HALB_PORT_K8S \
    || echo "Use \`nc -zv $HALB_VIP $HALB_PORT_K8S\` to test connectivity"

# @ ping : Verify HA (failover) dynamics
[[ $(type -t ping) ]] && {
    echo '
        Verify FAILOVER (HA) dynamics:
        
        While ping is running, 
        shutdown the keepalived MASTER node.

        Connectivity should persist as long as 
        at least one HA-LB node is running.

        PRESS ENTER when ready to test. 

        Use CTRL+C to kill.
    '
    read
    ping -4 -D $HALB_VIP
} || echo "Use \`ping -4 -D $HALB_VIP\` to verify failover (HA) when keepalived MASTER node is offline."
