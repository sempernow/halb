##############################################################################
## Makefile.settings : Environment Variables for Makefile(s)
#include Makefile.settings
# … ⋮ ︙ • “” ‘’ – — ™ ® © ± ° ¹ ² ³ ¼ ½ ¾ ÷ × ₽ € ¥ £ ¢ ¤ ♻  ⚐ ⚑
# ☢  ☣  ☠  ¦ ¶ § † ‡ ß µ ø Ø ƒ Δ ☡ ☈ ☧ ☩ ✚ ☨ ☦  ☓ ♰ ♱ ✖  ☘  웃 𝐀𝐏𝐏 𝐋𝐀𝐁
# ⚠️️ ✅ 🚀 🚧 🛠️ 🔧 🔍 🧪 👈 ⚡ ❌ 💡 🔒 📊 📈 🧩 📦 🧳 🥇 ✨️ 🔚
##############################################################################
## Environment variable rules:
## - Any TRAILING whitespace KILLS its variable value and may break recipes.
## - ESCAPE only that required by the shell (bash).
## - Environment hierarchy:
##   - Makefile environment OVERRIDEs OS environment lest set using `?=`.
##  	 - `FOO ?= bar` is overridden by parent setting; `export FOO=new`.
##  	 - `FOO :=`bar` is NOT overridden by parent setting.
##   - Docker YAML `env_file:` OVERRIDEs OS and Makefile environments.
##   - Docker YAML `environment:` OVERRIDEs YAML `env_file:`.
##   - CMD-inline OVERRIDEs ALL REGARDLESS; `make recipeX FOO=new BAR=new2`.

##############################################################################
## $(INFO) : Usage : `$(INFO) 'What ever'` prints a stylized "@ What ever".
SHELL   := /bin/bash
YELLOW  := "\e[1;33m"
RESTORE := "\e[0m"
INFO    := @bash -c 'printf $(YELLOW);echo "@ $$1";printf $(RESTORE)' MESSAGE


##############################################################################
## Project Meta

export PRJ_ROOT := $(shell pwd)
export PRJ_GIT  := $(shell git config remote.origin.url)
export LOG_PRE  := make
export UTC      := $(shell date '+%Y-%m-%dT%H.%M.%Z')


##############################################################################
## HAProxy/Keepalived : HA Application Load Balancer (HALB)

export HALB_DOMAIN   ?= lime.lan
export HALB_FQDN     ?= kube.${HALB_DOMAIN}
export HALB_VIP      ?= 192.168.11.11
export HALB_VIP6     ?= 0:0:0:0:0:ffff:c0a8:0b0b
export HALB_MASK     ?= 24
export HALB_CIDR     ?= ${HALB_VIP}/${HALB_MASK}
export HALB_DEVICE   ?= eth0

export HALB_FQDN_1   ?= a1.${HALB_DOMAIN}
export HALB_FQDN_2   ?= a2.${HALB_DOMAIN}
export HALB_FQDN_3   ?= a3.${HALB_DOMAIN}

export HALB_PORT_STATS ?= 8404
export HALB_PORT_K8S   ?= 8443
export HALB_PORT_HTTP  ?= 30080
export HALB_PORT_HTTPS ?= 30443


##############################################################################
## ansibash

## Public-key string of ssh user must be in ~/.ssh/authorized_keys of ADMIN_USER at all targets.
#export ADMIN_USER          ?= $(shell id -un)
export ADMIN_USER          ?= u2
export ADMIN_KEY           ?= ${HOME}/.ssh/vm_lime
export ADMIN_HOST          ?= a0
export ADMIN_NODES_CONTROL ?= a1 a2 a3
export ADMIN_TARGET_LIST   ?= ${ADMIN_NODES_CONTROL}
export ADMIN_SRC_DIR       ?= $(shell pwd)
#export ADMIN_DST_DIR       ?= ${ADMIN_SRC_DIR}
export ADMIN_DST_DIR       ?= /tmp/$(shell basename "${ADMIN_SRC_DIR}")

export ANSIBASH_TARGET_LIST ?= ${ADMIN_TARGET_LIST}
export ANSIBASH_USER        ?= ${ADMIN_USER}


##############################################################################
## Recipes : Meta

menu :
	$(INFO) 'Install HA Application Load Balancer (HALB) onto all target hosts : RHEL9 is expected'
	@echo "upgrade      : dnf upgrade"
	@echo "selinux      : Set SELinux mode"
	@echo "reboot       : Reboot hosts"
	@echo "rpms         : Install HAProxy/Keepalived"
	@echo "============== "
	@echo "Install      : Install HALB by recipes : firewall build push conf"
	@echo "  firewall   : Configure firewalld of target hosts for HALB"
	@echo "  build      : Generate HALB configurations from .tpl files"
	@echo "  push       : Push the app-config files to target hosts"
	@echo "  conf       : Configure HALB on target hosts"
	@echo "update       : Update /etc/…/haproxy.cfg & /etc/…/keepalived.conf"
	@echo "show         : Show HALB processes"
	@echo "log          : Selected recent app logs : journalctl -eu …"
	@echo "test         : Test HALB failover"
	@echo "stats        : GET http://<HOST>:${HALB_PORT_STATS}/stats/ | HAProxy web page"
	@echo "healthz      : GET https://<HOST>:${HALB_PORT_K8S}/healthz | K8s API server"
	@echo "============== "
	@echo "teardown     : Teardown HAProxy and Keepalived; remove vIP from network device"
	@echo "============== "
	@echo "scan         : Nmap scan report"
	@echo "status       : Print targets' status"
	@echo "sealert      : sealert -l '*'"
	@echo "net          : Interfaces' info"
	@echo "ruleset      : nftables rulesets"
	@echo "iptables     : iptables"
	@echo "psrss        : Print targets' top memory usage : RSS [MiB]"
	@echo "userrc       : Configure targets' bash shell using latest @ github.com/sempernow/userrc.git"
	@echo "============== "
	@echo "env          : Print the make environment"
	@echo "mode         : Fix folder and file modes of this project"
	@echo "eol          : Fix line endings : Convert all CRLF to LF"
	@echo "html         : Process all markdown (MD) to HTML"
	@echo "commit       : Commit and push this source"

env :
	$(INFO) 'Environment'
	@echo "PWD=${PRJ_ROOT}"
	@env |grep ADMIN_
	@env |grep ANSIBASH_

eol :
	find . -type f ! -path '*/.git/*' -exec dos2unix {} \+
mode :
	find . -type d ! -path './.git/*' -exec chmod 0755 "{}" \;
	find . -type f ! -path './.git/*' -exec chmod 0644 "{}" \;
#	find . -type f ! -path './.git/*' -iname '*.sh' -exec chmod 0755 "{}" \;
tree :
	tree -d |tee tree-d
html :
	find . -type f ! -path './.git/*' -name '*.md' -exec md2html.exe "{}" \;
commit : html mode
	gc && git push && gl && gs


##############################################################################
## Recipes : Host

# Scan subnet (CIDR) for IP addresses in use (running machines).
# - Manually validate that HALB_VIP is set to an *unused* address (within subnet CIDR).
# - Note this does not guarantee that an available VIP will remain so.
# - Protecting a VIP requires network admin.
scan :
	sudo nmap -sn ${HALB_CIDR} \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.scan.nmap.${UTC}.log
#	sudo arp-scan --interface ${HALB_DEVICE} --localnet \
#	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.scan.arp-scan.${UTC}.log

# Smoke test this setup
status :
	ansibash 'printf "%12s: %s\n" Host $$(hostname) \
	    && printf "%12s: %s\n" User $$(id -un) \
	    && printf "%12s: %s\n" Kernel $$(uname -r) \
	    && printf "%12s: %s\n" firewalld $$(systemctl is-active firewalld.service) \
	    && printf "%12s: %s\n" SELinux $$(getenforce) \
	    && printf "%12s: %s\n" haproxy $$(systemctl is-active haproxy) \
	    && printf "%12s: %s\n" keepalived $$(systemctl is-active keepalived) \
	    && printf "%12s: %s\n" kubelet $$(systemctl is-active kubelet) \
	  '
sealert :
	ansibash 'sudo sealert -l "*" |grep -e == -e "Source Path" -e "Last Seen" |grep -v 2024 |grep -B1 -e == -e "Last Seen"'
net:
	ansibash '\
	    sudo nmcli dev status; \
	    ip -brief addr; \
	  '
ruleset:
	ansibash sudo nft list ruleset
iptables:
	ansibash sudo iptables -L -n -v

psrss :
	ansibash -s scripts/psrss.sh

userrc :
	ansibash 'git clone https://github.com/sempernow/userrc 2>/dev/null || echo ok'
	ansibash 'pushd userrc && git pull && make sync-user && make user'

reboot :
	ansibash sudo reboot

upgrade :
	ansibash sudo dnf -y --color=never upgrade \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.upgrade.${UTC}.log
selinux :
	ansibash -s ${ADMIN_SRC_DIR}/configure-selinux.sh enforcing \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.selinux.${UTC}.log

rpms :
	ansibash sudo dnf -y install conntrack haproxy keepalived \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.rpms.${UTC}.log

install : firewall build push conf
firewall :
	ansibash -u firewalld-halb.sh
	ansibash sudo bash firewalld-halb.sh ${HALB_PORT_K8S} ${HALB_PORT_STATS}
build :
	bash ${ADMIN_SRC_DIR}/build-halb.sh
push :
	scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_1}.conf ${ADMIN_USER}@${HALB_FQDN_1}:keepalived.conf \
	    && scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_2}.conf ${ADMIN_USER}@${HALB_FQDN_2}:keepalived.conf \
	    && scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_3}.conf ${ADMIN_USER}@${HALB_FQDN_3}:keepalived.conf \
	    && ansibash -u ${ADMIN_SRC_DIR}/haproxy.cfg \
	    && ansibash -u ${ADMIN_SRC_DIR}/configure-halb.sh \
	    && ansibash -u ${ADMIN_SRC_DIR}/systemd/keepalived.10-options.conf \
	    && ansibash -u ${ADMIN_SRC_DIR}/systemd/haproxy.10-limits.conf \
	    && ansibash -u ${ADMIN_SRC_DIR}/systemd/haproxy.20-quiet.conf \
	    && ansibash -u ${ADMIN_SRC_DIR}/haproxy-rsyslog.conf
pre :
	ansibash 'sudo haproxy -c -f haproxy.cfg && sudo keepalived -n -l -f keepalived.conf'
conf :
	  ansibash sudo bash configure-halb.sh \
	      |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.conf.${UTC}.log
update :
	  ansibash sudo bash configure-halb.sh update \
	      |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.update.${UTC}.log
show :
	ansibash ip -4 -brief addr show dev ${HALB_DEVICE}
	ansibash 'sudo journalctl -eu keepalived |grep -e Entering -e @'
log :
	ansibash  "sudo journalctl -eu haproxy --no-pager |grep -e == -e DOWN |tail -n 20"
	ansibash  "sudo journalctl -eu keepalived --no-pager |tail -n 20"
test :
	bash ${ADMIN_SRC_DIR}/test-failover.sh
stats :
	curl -sIX GET http://${HALB_VIP}:${HALB_PORT_STATS}/stats/ |grep HTTP || echo ERR : $$?
	curl -sIX GET http://${HALB_FQDN}:${HALB_PORT_STATS}/stats/ |grep HTTP || echo ERR : $$?
	curl -sIX GET http://${HALB_FQDN_1}:${HALB_PORT_STATS}/stats/ |grep HTTP || echo ERR : $$?
	curl -sIX GET http://${HALB_FQDN_2}:${HALB_PORT_STATS}/stats/ |grep HTTP || echo ERR : $$?
	curl -sIX GET http://${HALB_FQDN_3}:${HALB_PORT_STATS}/stats/ |grep HTTP || echo ERR : $$?
healthz :
	curl -ksfIX GET https://${HALB_VIP}:${HALB_PORT_K8S}/healthz/ |grep HTTP || echo ERR : $$?
	curl -ks https://${HALB_FQDN}:${HALB_PORT_K8S}/healthz?verbose || echo ERR : $$?
teardown :
	ansibash -u teardown.sh
	ansibash sudo bash teardown.sh '${HALB_VIP}' '${HALB_MASK}' '${HALB_DEVICE}'
