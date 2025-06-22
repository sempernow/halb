#!/usr/bin/env bash
#
## Request to ngx app by socat client using PROXY protocol
#
client=${1:-172.24.217.171} # ip at current shell
cport=${2:-80}              # K8s Pod port
server=${3:-192.168.11.101} # K8s Service port
sport=${4:-30080} # HAProxy k8s-ingress backend (upstream) port

echo -en "PROXY TCP4 $client $server $cport $sport\r\nGET /meta/ HTTP/1.1\r\nHost: $server\r\n\r\n" \
    |socat - TCP4:$server:$sport
