#!/usr/bin/env bash
#/usr/sbin/pidof haproxy > /dev/null 2>&1
/usr/bin/systemctl is-active haproxy > /dev/null 2>&1