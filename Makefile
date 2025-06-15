##############################################################################
## Makefile.settings : Environment Variables for Makefile(s)
#include Makefile.settings
# … ⋮ ︙ • “” ‘’ – — ™ ® © ± ° ¹ ² ³ ¼ ½ ¾ ÷ × ₽ € ¥ £ ¢ ¤ ♻  ⚐ ⚑
# ☢  ☣  ☠  ¦ ¶ § † ‡ ß µ ø Ø ƒ Δ ☡ ☈ ☧ ☩ ✚ ☨ ☦  ☓ ♰ ♱ ✖  ☘  웃 𝐀𝐏𝐏 𝐋𝐀𝐁
# ⚠  ✅ 🚀 🚧 🛠️ 🔧 🔍 🧪 ⚡ ❌ 💡 🔒 📊 📈 🧩 📦 🧳 🥇 ✨️ 🔚
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
export LOG_PRE  := make
export UTC      := $(shell date '+%Y-%m-%dT%H.%M.%Z')

##############################################################################
## HAProxy/Keepalived : HA Application Load Balancer (HALB)

export HALB_DOMAIN   ?= lime.lan
export HALB_VIP      ?= 192.168.11.11
export HALB_VIP6     ?= 0:0:0:0:0:ffff:c0a8:0b0b
export HALB_MASK     ?= 24
export HALB_CIDR     ?= ${HALB_VIP}/${HALB_MASK}
export HALB_DEVICE   ?= eth0
export HALB_FQDN_1   ?= a1.${HALB_DOMAIN}
export HALB_FQDN_2   ?= a2.${HALB_DOMAIN}
export HALB_FQDN_3   ?= a3.${HALB_DOMAIN}
export HALB_K8S      ?= 8443
export HALB_HTTP     ?= 30080
export HALB_HTTPS    ?= 30443


##############################################################################
## ansibash

## Public-key string of ssh user must be in ~/.ssh/authorized_keys of ADMIN_USER at all targets.
#export ADMIN_USER          ?= $(shell id -un)
export ADMIN_USER          ?= u2
export ADMIN_KEY           ?= ${HOME}/.ssh/vm_lime
export ADMIN_HOST          ?= a0
export ADMIN_NODES_CONTROL ?= a1 a2 a3
export ADMIN_NODES_WORKER  ?=
export ADMIN_TARGET_LIST   ?= ${ADMIN_NODES_CONTROL} ${ADMIN_NODES_WORKER}
export ADMIN_SRC_DIR       ?= $(shell pwd)
#export ADMIN_DST_DIR       ?= ${ADMIN_SRC_DIR}
export ADMIN_DST_DIR       ?= /tmp/$(shell basename "${ADMIN_SRC_DIR}")

export ANSIBASH_TARGET_LIST ?= ${ADMIN_TARGET_LIST}
export ANSIBASH_USER        ?= ${ADMIN_USER}


##############################################################################
## Recipes : Meta

menu :
	$(INFO) 'Install HA Application Load Balancer onto all target hosts : RHEL9 is expected'
	@echo "update-os    : Update host OS"
	@echo "conf         : kernel selinux swap : See scripts/configure-*"
	@echo "  -selinux   : Configure targets' SELinux"
	@echo "reboot       : Reboot targets"
	@echo "rpms         : Install HAProxy/Keepalived and host tools"
	@echo "============== "
	@echo "lbmake       : Generate HA-LB configurations from .tpl files"
	@echo "lbconf       : Configure HA LB on all control nodes"
	@echo "lbverify     : Verify HA-LB dynamics"
	@echo "lbshow       : Show HA-LB status"
	@echo "============== "
	@echo "teardown     : kubeadm reset and cleanup at target node(s)"
	@echo "============== "
	@echo "scan         : Nmap scan report"
	@echo "status       : Print targets' status"
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
	@env |grep K8S_
	@env |grep ADMIN_
	@env |grep DOMAIN_

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
commit push : html mode
	gc && git push && gl && gs

##############################################################################
## Recipes : Host

# Scan subnet (CIDR) for IP addresses in use (running machines).
# - Manually validate that HALB_VIP is set to an *unused* address (within subnet CIDR).
# - Note this does not guarantee that an available VIP will remain so.
# - Protecting a VIP requires network admin.
scan :
	sudo nmap -sn ${HALB_CIDR} \
	  |& tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.scan.nmap.${UTC}.log
#	sudo arp-scan --interface ${HALB_DEVICE} --localnet \
#	  |& tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.scan.arp-scan.${UTC}.log

# Smoke test this setup
status hello :
	@ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash 'printf "%12s: %s\n" Host $$(hostname) \
	    && printf "%12s: %s\n" User $$(id -un) \
	    && printf "%12s: %s\n" Kernel $$(uname -r) \
	    && printf "%12s: %s\n" firewalld $$(systemctl is-active firewalld.service) \
	    && printf "%12s: %s\n" SELinux $$(getenforce) \
	    && printf "%12s: %s\n" containerd $$(systemctl is-active containerd) \
	    && printf "%12s: %s\n" kubelet $$(systemctl is-active kubelet) \
	  '

#net: ruleset iptables
net:
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash '\
	    sudo nmcli dev status; \
	    ip -brief addr; \
	  '
ruleset:
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash sudo nft list ruleset
iptables:
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash sudo iptables -L -n -v

psrss :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash -s scripts/psrss.sh

# Configure bash shell of target hosts using the declared Git project
userrc :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash 'git clone https://github.com/sempernow/userrc 2>/dev/null || echo ok'
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash 'pushd userrc && git pull && make sync-user && make user'

reboot :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash sudo reboot

## Host config
conf : conf-update conf-kernel conf-selinux conf-swap
conf-update :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash sudo dnf -y update \
	  |& tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.conf-update.${UTC}.log
conf-sudoer :
	bash make.recipes.sh sudoer \
	  |& tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.conf-sudoer.${UTC}.log

conf-selinux :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash -s ${ADMIN_SRC_DIR}/configure-selinux.sh enforcing \
	  |& tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.conf-selinux.${UTC}.log

## Install K8s and all deps : RPM(s), binaries, systemd, and other configs
rpms : update-os
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash -s ${ADMIN_SRC_DIR}/install-rpms.sh \
	  |& tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.install-rpms.${UTC}.log
update-os :
	ANSIBASH_TARGET_LIST='${ADMIN_TARGET_LIST}' \
	  ansibash sudo dnf -y --color=never update \
	  |& tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.update-os.${UTC}.log

#lbclean :
#ansibash -s ${ADMIN_SRC_DIR}/clean-halb.sh ${HALB_VIP} ${HALB_DEVICE}
#ansibash -s ${ADMIN_SRC_DIR}/configure-halb.sh ${HALB_VIP} ${HALB_DEVICE}

#ansibash sudo ip addr del ${HALB_VIP}/24 dev ${HALB_DEVICE}

#bash make.recipes.sh halb
lbmake lbbuild :
	bash ${ADMIN_SRC_DIR}/build-halb.sh

#bash halb/push-halb.sh
lbconf :
	scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_1}.conf ${GITOPS_USER}@${HALB_FQDN_1}:keepalived.conf \
	  && scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_2}.conf ${GITOPS_USER}@${HALB_FQDN_2}:keepalived.conf \
	  && scp -p ${ADMIN_SRC_DIR}/keepalived-${HALB_FQDN_3}.conf ${GITOPS_USER}@${HALB_FQDN_3}:keepalived.conf \
	  && ansibash -u ${ADMIN_SRC_DIR}/systemd/99-keepalived.conf \
	  && ansibash -u ${ADMIN_SRC_DIR}/keepalived-check_apiserver.sh \
	  && ansibash -u ${ADMIN_SRC_DIR}/haproxy.cfg \
	  && ansibash -u ${ADMIN_SRC_DIR}/haproxy-rsyslog.conf \
	  && ansibash -u ${ADMIN_SRC_DIR}/etc.hosts \
	  && ansibash -u ${ADMIN_SRC_DIR}/etc.environment \
	  && ansibash -s ${ADMIN_SRC_DIR}/configure-halb.sh ${HALB_CIDR} ${HALB_DEVICE} \
	  |& tee ${ADMIN_SRC_DIR}/logs/${LOG_PRE}.lbconf.${UTC}.log

lbverify :
	bash ${ADMIN_SRC_DIR}/verify-instruct.sh

lbshow lblook :
#ansibash ip -4 -brief addr show dev ${HALB_DEVICE} |grep -e ${HALB_VIP} -e ===
	ansibash ip -4 -brief addr show dev ${HALB_DEVICE}
	ansibash 'sudo journalctl -eu keepalived |grep -e Entering -e @'

healthz :
	curl -ks https://${HALB_VIP}:${HALB_K8S}/healthz?verbose

teardown :
	@echo "  NOT IMPLEMENTED"
