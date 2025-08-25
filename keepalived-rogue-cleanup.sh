#!/bin/bash
###############################################################
# Kill rogue keepalived processes not under systemd control
# that otherwise cause (re)start failure of systemd service.
# - Install to : 
#   /usr/local/bin/keepalive-rogue-cleanup.sh
# - Called by keepalived systemd drop-in :
#   /etc/systemd/system/keepalived.service.d/10-options.conf
###############################################################
main_pid="$(systemctl show -p MainPID keepalived |cut -d= -f2)"
for pid in $(pidof keepalived); do
    ppid=$(ps -o ppid= -p "$pid" |xargs)
    if [[ "$pid" != "$main_pid" && "$ppid" != "1" ]]; then
        echo "Killing rogue keepalived process $pid (PPID: $ppid)"
        kill -9 "$pid"
    fi
done
