#!/usr/bin/env bash
#################################################################
# See recipes of Makefile
#################################################################

rebootSoft(){
    awaitNodeReady(){
        node=$1
        timeout=300
        elapsed=0
        interval=5

        echo -e "\n⌛ K8s : Await 'Ready' status of node $node"
        while true; do
            status=$(kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "NotFound")
            [[ "$status" == "True" ]] && {
                echo -e "✅ K8s : Node $node is Ready.\n"
                break
            }
            (( elapsed >= timeout )) && {
                echo -e "❌ K8s : Node $node status remains NOT Ready after $timeout seconds.\n"
                
                return 11
            }
            sleep $interval
            ((elapsed += interval))
        done
    }
    export -f awaitNodeReady
    nodes="$@"
    domain=${HALB_DOMAIN:-HALB_DOMAIN}
    flag_node_timeout=''

    [[ $(kubectl config get-contexts --no-headers) ]] || {
        printf "%s\n   %s\n" \
            "❌ This method requires client (kubectl) communication with K8s API;" \
            "however, kubectl is entirely unconfigured; has no kubeconfig."
            return 1
    }

    echo -e "🛠️ === $FUNCNAME : Soft reboot of K8s nodes: $nodes : drain ➔  reboot ➔  uncordon"

    for node in $nodes; do

        [[ $flag_node_timeout ]] && {
            echo "⚠️ Skip this node ($node) because prior node ($flag_node_timeout) FAILED TO RECOVER from its reboot within timeout."
            break
        }
        nslookup $node.$domain >/dev/null 2>&1 || { 
            echo "⚠️ Skip this node ($node) because DNS does NOT RESOLVE '$node.$domain'"
            break
        }
        echo -e "\n🔧 === Node: $node"

        echo -e "\nℹ️ K8s : Cordon and drain node $node ..."
        ## Failure of cordon/drain may occur due to various causes local to that node. 
        ## Continue to process other nodes regardless of cordon/drain failure,
        ## and handle such problemed node(s) issues manually afterward.
        kubectl drain $node --ignore-daemonsets --delete-emptydir-data --force || {
            echo "❌ K8s : ERR at kubectl drain $node ..." 
            # Undo the effect of (failed) drain; allow K8s to schedule new Pods here as we process (drain) other nodes.
            kubectl uncordon $node 
            break
        }

        echo -e "\nℹ️ Host : Command reboot of node $node ..."
        ssh -t $node 'sudo reboot;sleep 300'
        echo -e "ℹ️ Host : ...node $node is rebooting." 

        ## If this K8s Node fails to recover (STATUS: Ready) after reboot (within declared timeout), 
        ## then we don't do anything to any other nodes remaining of this loop.
        awaitNodeReady $node || export flag_node_timeout=$node
        
        ## Bypass the External Load Balancer to hit an endpoint at *this* node's instance of K8s API server.
        request="https://$node.$domain:6443/healthz"
        echo -e "⌛ K8s : Await expected response from API server on subject node : $request"
        while true; do
            curl -fksIX GET --connect-timeout 3 $request |grep -v 50 |grep HTTP &&
                break
            sleep 5
        done

        echo -e "\nℹ️ K8s : Uncordon node $node ..."
        kubectl uncordon $node

    done

    echo -e "\n✅ $FUNCNAME : Completed."
}

"$@" || echo "❌  ERR : $?" >&2
