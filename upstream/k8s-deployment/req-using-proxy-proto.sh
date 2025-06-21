#!/usr/bin/env bash
#
## Request (by socat client) using PROXY protocol
#
client=${1:-172.24.217.171}
cport=${2:-80}
server=${3:-192.168.11.101}
# HAProxy frontend @ http listener
sport=${4:-30080}

echo -en "PROXY TCP4 $client $server $cport $sport\r\nGET /meta/ HTTP/1.1\r\nHost: $server\r\n\r\n" \
    |socat - TCP4:$server:$sport

exit $?
#######
#
## Response (example)
#
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Sun, 20 Apr 2025 17:56:34 GMT
Content-Type: application/octet-stream
Content-Length: 99
Connection: keep-alive
Content-Type: application/json

{"host": "ngx-77d4cb7d8-2ffxr", "client_ip": "172.24.217.171", "date": "2025-04-20T17:56:34+00:00"}

