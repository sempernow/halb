#!/bin/bash
echo "=== Current denials ==="
sudo ausearch -c keepalived -m avc --raw | sudo audit2allow -R

echo -e "\n=== Current module content ==="
sudo semodule -e keepalived_custom

echo -e "\n=== Check if module provides needed rules ==="
# Get required permissions from current denials
REQUIRED="$(sudo ausearch -c keepalived -m avc --raw | sudo audit2allow -R | grep allow)"
echo "Required:"
echo "$REQUIRED"

echo -e "\n=== Module provides ==="
sudo sesearch -A --allow |grep keepalived
