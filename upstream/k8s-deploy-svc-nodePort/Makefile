APP := ngx

client  ?= 172.24.217.171
cport   ?= 80
server  ?= 192.168.11.101
sport   ?= 30080

info : 
	cat Makefile

build :
	cat ${APP}.deploy.yaml ${APP}.cm.yaml ${APP}.svc.yaml |tee ${APP}.yaml

buildsans :
	cat ${APP}.deploy.yaml ${APP}.cm.sans-proxy-proto.yaml ${APP}.svc.yaml |tee ${APP}.yaml

deploy :
	kubectl apply -f ${APP}.yaml 

req :
	bash req-using-proxy-proto.sh ${client} ${cport} ${server} ${sport}
reqsans :
	curl http://${server}:${sport}/meta || echo ERR
reqsansall reqallsans :
	kubectl get node -o yaml |yq '.items[].status.addresses[] |select(.type == "InternalIP").address' |xargs -I{} curl -s http://{}:30080/meta/ |jq . --slurp

down teardown : 
	kubectl delete -f ${APP}.yaml
