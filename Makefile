##############################################################################
## Makefile.settings : Environment Variables for Makefile(s)
#include Makefile.settings
# … ⋮ ︙ • ● – — ™ ® © ± ° ¹ ² ³ ¼ ½ ¾ ÷ × ₽ € ¥ £ ¢ ¤ ♻ ⚐ ⚑ ✪ ❤  \ufe0f
# ☢ ☣ ☠ ¦ ¶ § † ‡ ß µ Ø ƒ Δ ☡ ☈ ☧ ☩ ✚ ☨ ☦ ☓ ♰ ♱ ✖  ☘  웃 𝐀𝐏𝐏 🡸 🡺 ➔
# ℹ️ ⚠️ ✅ ⌛ 🚀 🚧 🛠️ 🔧 🔍 🧪 👈 ⚡ ❌ 💡 🔒 📊 📈 🧩 📦 🥇 ✨️ 🔚
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
## $(INFO) : USAGE : `$(INFO) "Any !"` in recipe prints quoted str, stylized.
SHELL   := /bin/bash
YELLOW  := "\e[1;33m"
RESTORE := "\e[0m"
INFO    := @bash -c 'printf $(YELLOW);echo "$$1";printf $(RESTORE)' MESSAGE


##############################################################################
## Project Meta

export PRJ_ROOT := $(shell pwd)
export PRJ_GIT  := $(shell git config remote.origin.url)
export LOG_PRE  := make
export UTC      := $(shell date '+%Y-%m-%dT%H.%M.%Z')


##############################################################################
## HAProxy/Keepalived : HA Network Load Balancer (HALB)

export HALB_PROJECT      ?= github.com/sempernow/halb
export HALB_DOMAIN       ?= lime.lan
export HALB_FQDN         ?= kube.${HALB_DOMAIN}
export HALB_HOSTS        ?= a1 a2 a3
export HALB_FQDN_1       ?= a1.${HALB_DOMAIN}
export HALB_FQDN_2       ?= a2.${HALB_DOMAIN}
export HALB_FQDN_3       ?= a3.${HALB_DOMAIN}
export HALB_UPSTREAM_1   ?= a1.${HALB_DOMAIN}
export HALB_UPSTREAM_2   ?= a2.${HALB_DOMAIN}
export HALB_UPSTREAM_3   ?= a3.${HALB_DOMAIN}
export HALB_MASK         ?= 24
export HALB_MASK6        ?= 64
export HALB_DOMAIN_CIDR  ?= 192.168.11.0/${HALB_MASK}
export HALB_DOMAIN_CIDR6 ?= fd00:11::/${HALB_MASK6}
export HALB_VIP          ?= 192.168.11.11
export HALB_VIP6         ?= fd00:11::100
export HALB_CIDR         ?= ${HALB_VIP}/${HALB_MASK}
export HALB_CIDR6        ?= ${HALB_VIP6}/${HALB_MASK6}
export HALB_DEVICE       ?= eth0
export HALB_ZONE         ?= k8s-external
export HALB_PORT_STATS   ?= 8404
export HALB_PORT_K8S     ?= 8443
export HALB_PORT_HTTP    ?= 30080
export HALB_PORT_HTTPS   ?= 30443

export DOMAIN_CA_CERT := ${PRJ_ROOT}/domain-root-CA.crt

##############################################################################
## Admin

## Public-key string of ssh user must be in ~/.ssh/authorized_keys of ADMIN_USER at all targets.
#export ADMIN_USER            ?= $(shell id -un)
export ADMIN_USER            ?= u2
export ADMIN_KEY             ?= ${HOME}/.ssh/vm_lime
export ADMIN_HOST            ?= a0
export ADMIN_TARGET_LIST     ?= ${HALB_HOSTS}
export ADMIN_SRC_DIR         ?= $(shell pwd)
#export ADMIN_DST_DIR         ?= ${ADMIN_SRC_DIR}
export ADMIN_DST_DIR         ?= /tmp/$(shell basename "${ADMIN_SRC_DIR}")

export ADMIN_JOURNAL_SINCE   ?= 15 minute ago

export ANSIBASH_TARGET_LIST  ?= ${ADMIN_TARGET_LIST}
export ANSIBASH_USER         ?= ${ADMIN_USER}


##############################################################################
## Recipes : Meta

menu :
	$(INFO) '🧩  Install HA Load Balancer (HALB) onto target hosts'
	@echo "    - Target hosts expected: RHEL 8+"
	@echo "    - See https://${HALB_PROJECT}"
	$(INFO) "🚧  1. Prepare targets for HALB"
	@echo "rpms         : Install HAProxy/Keepalived"
	@echo "reboot       : Hard reboot of ${HALB_HOSTS}"
	$(INFO) "🚀  2. Provision targets with HALB"
	@echo "fw-set       : Configure firewalld (zone ${HALB_ZONE}) of target hosts for HALB"
	@echo "install      : Install HALB"
	@echo "  build      : Generate HALB configurations from .tpl files"
	@echo "  push       : Push the HALB config files to target hosts"
	@echo "  conf       : Configure HALB on target hosts"
	@echo "update       : Update HALB (haproxy.cfg, keepalived.conf)"
	$(INFO) "🔍  Inspect"
	@echo "log          : journalctl … (all nodes)"
	@echo "  -fw        : Log of all dropped packets (DROP) on device ${HALB_DEVICE} … --since='${ADMIN_JOURNAL_SINCE}'"
	@echo "  -haproxy   : Log of 'DOWN' upstreams"
	@echo "  -keepalived: Log of 'Entering' (MASTER/BACKUP) state changes"
	@echo "  -recent    : Unfiltered logs of both haproxy and keepalived … --since='${ADMIN_JOURNAL_SINCE}'"
	@echo "health       : GET : HTTP responses"
	@echo "status       : Print targets' status"
	@echo "ausearch     : SELinux : ausearch -m AVC,... -ts recent"
	@echo "sealert      : SELinux : sealert -l '*'"
	@echo "net          : Interfaces' info"
	@echo "vip          : Show which node has the vIP"
	@echo "ruleset      : nftables rulesets"
	@echo "iptables     : iptables"
	@echo "fw-get       : List fw rules"
	@echo "psrss        : Top RSS usage"
	@echo "pscpu        : Top CPU usage"
	@echo "scan         : Nmap scan report"
	$(INFO) "🧪  Test"
	@echo "bench         : Load test : ab -c ... -n ... https://${HALB_VIP}:${HALB_PORT_K8S}/healthz?verbose"
	@echo "failover     : Test HALB failover"
	$(INFO) "⚠️  Teardown"
	@echo "teardown     : HALB teardown"
	$(INFO) "🛠️  Maintenance"
	@echo "userrc       : Install onto targets the latest shell scripts of github.com/sempernow/userrc.git"
	@echo "env          : Print the make environment"
	@echo "mode         : Fix folder and file modes of this project"
	@echo "eol          : Fix line endings : Convert all CRLF to LF"
	@echo "html         : Process all markdown (MD) to HTML"
	@echo "commit       : Commit and push this source"

env :
	$(INFO) 'Environment'
	@echo "PWD=${PRJ_ROOT}"
	@env |grep HALB_ |sort
	@echo
	@env |grep ADMIN_ |sort
	@echo
	@env |grep ANSIBASH_ |sort

eol :
	find . -type f ! -path '*/.git/*' -exec dos2unix {} \+
mode :
	find . -type d ! -path './.git/*' -exec chmod 0755 "{}" \;
	find . -type f ! -path './.git/*' -exec chmod 0640 "{}" \;
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
	@ansibash 'printf "%12s: %s\n" Host $$(hostname) \
	    && printf "%12s: %s\n" User $$(id -un) \
	    && printf "%12s: %s\n" Kernel $$(uname -r) \
	    && printf "%12s: %s\n" firewalld $$(systemctl is-active firewalld.service) \
	    && printf "%12s: %s\n" SELinux $$(getenforce) \
	    && printf "%12s: %s\n" haproxy $$(systemctl is-active haproxy) \
	    && printf "%12s: %s\n" keepalived $$(systemctl is-active keepalived) \
	    && printf "%12s: %s\n" kubelet $$(systemctl is-active kubelet) \
	    && printf "%12s: %s\n" uptime "$$(uptime)" \
	  '
ausearch :
	ansibash sudo ausearch -m AVC,USER_AVC,SELINUX_ERR,USER_SELINUX_ERR -ts recent \
	  |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.ausearch.${UTC}.log
sealert :
	ansibash 'sudo sealert -l "*" |grep -e == -e "Source Path" -e "Last" |tail -n 20'
net :
	ansibash 'sudo nmcli dev status'
vip :
	ansibash ip -4 -brief addr show dev ${HALB_DEVICE}
ruleset :
	ansibash sudo nft list ruleset
iptables :
	ansibash sudo iptables -L -n -v

psrss :
	ansibash -s psrss.sh
pscpu :
	ansibash -s pscpu.sh

userrc :
	ansibash 'git clone https://github.com/sempernow/userrc 2>/dev/null || echo ok'
	ansibash 'pushd userrc && git pull && make sync-user && make user'

reboot : 
	ansibash sudo reboot

rpms :
	ansibash sudo dnf -y install conntrack haproxy keepalived psmisc \
	    |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.rpms.${UTC}.log

install : fw-set rpms build push conf

fw-set  :
	ansibash -u firewall-halb.sh
	ansibash sudo bash firewall-halb.sh ${HALB_PORT_K8S} ${HALB_PORT_STATS}
fw-get :
	ansibash -u firewall-get.sh
	ansibash 'sudo bash firewall-get.sh || echo "⚠️  ERR : $$?"'

build :
	bash ${ADMIN_SRC_DIR}/build-halb.sh
push :
	    ansibash -u ${ADMIN_SRC_DIR}/configure-halb.sh \
	    && ansibash -u ${ADMIN_SRC_DIR}/haproxy.cfg \
	    && ansibash -u ${ADMIN_SRC_DIR}/systemd/haproxy.10-limits.conf \
	    && ansibash -u ${ADMIN_SRC_DIR}/systemd/haproxy.20-quiet.conf \
	    && ansibash -u ${ADMIN_SRC_DIR}/haproxy-rsyslog.conf \
	    && ansibash -u ${ADMIN_SRC_DIR}/systemd/keepalived.10-options.conf \
	    && ansibash -u ${ADMIN_SRC_DIR}/keepalived-rogue-cleanup.sh \
	    && ansibash -u ${ADMIN_SRC_DIR}/keepalived-check-haproxy.sh \
	    && scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_1}.conf ${ADMIN_USER}@${HALB_FQDN_1}:keepalived.conf \
	    && scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_2}.conf ${ADMIN_USER}@${HALB_FQDN_2}:keepalived.conf \
	    && scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_3}.conf ${ADMIN_USER}@${HALB_FQDN_3}:keepalived.conf
conf :
	  ansibash sudo bash configure-halb.sh installConfig \
	      |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.conf.${UTC}.log
update : build
	ansibash -u ${ADMIN_SRC_DIR}/configure-halb.sh
	ansibash -u ${ADMIN_SRC_DIR}/haproxy.cfg
	ansibash -u ${ADMIN_SRC_DIR}/keepalived-check-haproxy.sh
	scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_1}.conf ${ADMIN_USER}@${HALB_FQDN_1}:keepalived.conf
	scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_2}.conf ${ADMIN_USER}@${HALB_FQDN_2}:keepalived.conf
	scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_3}.conf ${ADMIN_USER}@${HALB_FQDN_3}:keepalived.conf
	ansibash sudo bash configure-halb.sh updateConfig |tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.update.${UTC}.log
pre :
	ansibash 'sudo haproxy -c -f haproxy.cfg && sudo keepalived -n -l -f keepalived.conf'

log logs : log-haproxy log-keepalived
log-haproxy :
	ansibash  'systemctl is-active haproxy;sudo journalctl -eu haproxy --no-pager |grep -e == -e DOWN |tail -n 20'
log-keepalived :
#ansibash 'systemctl is-active keepalived;sudo journalctl -eu keepalived --no-pager |grep -e Entering -e @ |tail -n 20'
	ansibash 'systemctl is-active keepalived;sudo journalctl -eu keepalived --no-pager'
log-recent :
	ansibash  'sudo journalctl -eu haproxy --since="${ADMIN_JOURNAL_SINCE}" --no-pager --full'
	ansibash  'sudo journalctl -eu keepalived --since="${ADMIN_JOURNAL_SINCE}" --no-pager --full'
log-selinux :
	ansibash sudo ausearch -c keepalived -m avc -ts recent
log-fw fw-log fw-logs :
	ansibash "sudo journalctl --since='${ADMIN_JOURNAL_SINCE}' |grep DROP;echo All recent DROP logs from \'${ADMIN_JOURNAL_SINCE}\' until $$(date -Is)"

bench :
	type -t ab && ab -c 100 -n 10000 https://${HALB_VIP}:${HALB_PORT_K8S}/healthz?verbose || echo "🧩 Requires CLI utility: ab"
failover :
	bash ${ADMIN_SRC_DIR}/test-failover.sh
stats :
	curl -sIX GET http://${HALB_VIP}:${HALB_PORT_STATS}/stats/ |grep HTTP || echo ERR : $$?
	curl -sIX GET http://${HALB_FQDN}:${HALB_PORT_STATS}/stats/ |grep HTTP || echo ERR : $$?
	curl -sIX GET http://${HALB_FQDN_1}:${HALB_PORT_STATS}/stats/ |grep HTTP || echo ERR : $$?
	curl -sIX GET http://${HALB_FQDN_2}:${HALB_PORT_STATS}/stats/ |grep HTTP || echo ERR : $$?
	curl -sIX GET http://${HALB_FQDN_3}:${HALB_PORT_STATS}/stats/ |grep HTTP || echo ERR : $$?
healthz health : stats
	curl -ksfIX GET https://${HALB_VIP}:${HALB_PORT_K8S}/readyz |grep HTTP || echo ERR : $$?
	curl -ksfIX GET https://${HALB_FQDN}:${HALB_PORT_K8S}/readyz |grep HTTP || echo ERR : $$?

teardown :
	ansibash -u teardown.sh
	ansibash 'sudo bash teardown.sh "${HALB_VIP}" "${HALB_MASK}" "${HALB_DEVICE}"'

