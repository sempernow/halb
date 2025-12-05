#!/usr/bin/env bash
# haproxy-service-updater.sh
#########################################################
# Append a fronent-backend proxy pair for
# a Kubernetes Service of type LoadBalancer. 
#
#########################################################
# >>>  EXAMPLE ONLY : Parameterize this script    
#########################################################
[[ "$(id -u)" -ne 0 ]] && {
    echo "❌  ERR : MUST run as root" >&2

    exit 11
}
[[ -n $3 ]] || {
    echo "❌  ERR : Missing args" >&2

    exit 22
}

SERVICE_NAME=$1 # app-01-svc
SERVICE_PORT=$2 # 8080
NODE_PORT=$3    # 30001

# Generate frontend/backend config
CONFIG="
frontend ${SERVICE_NAME}_front
    bind *:${SERVICE_PORT}
    default_backend ${SERVICE_NAME}_back

backend ${SERVICE_NAME}_back
    option      tcp-check
    tcp-check   connect

    server a1 192.168.11.101:${NODE_PORT} check
    server a2 192.168.11.102:${NODE_PORT} check
    server a3 192.168.11.103:${NODE_PORT} check
"

# Update HAProxy config and reload
echo "$CONFIG" |tee -a /etc/haproxy/haproxy.cfg
haproxy -c -f /etc/haproxy/haproxy.cfg &&
    systemctl reload haproxy ||
        echo "❌  ERR : $? : haproxy -c -f ..." >&2

