#!/usr/bin/env bash
host=$1
cat <<EOH >/tmp/kube-version.json
{
  "major": "1",
  "minor": "27",
  "gitVersion": "v1.27.0",
  "platform": "linux/amd64"
}
EOH
echo "🛠️  Start NGINX container configured to mock K8s API server @ '$host'" 
app=mock-kube-apiserver
sudo podman ps |grep $app ||
    sudo podman run -d --rm \
        --name $app \
        -p 6443:80 \
        -v /tmp/kube-version.json:/usr/share/nginx/html/version:ro,Z \
        docker.io/library/nginx

echo
req="curl -sfIX GET http://$host/version"
echo "⚡  $req" 

seq 9 |xargs -n1 /bin/bash -c '
    rsp="$($0 |grep HTTP)" &&
        echo "✅  $rsp" ||
            echo "❌  $rsp"
    sleep 2
' "$req"

echo
echo "🚧  Teardown"
sudo podman container stop $app
