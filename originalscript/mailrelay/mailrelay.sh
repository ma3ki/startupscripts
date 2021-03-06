#!/bin/bash
#
# @sacloud-name "MailRelay"
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトはメールリレーサーバをセットアップします
# (このスクリプトは、CentOS7.Xでのみ動作します)
#
# このスクリプトはセットアップ完了のために、下記のDNS登録が必要です
# ・ホスト名のAレコードの登録
# ・IPアドレスの PTRレコードにホスト名を登録
# ・IPアドレスを ホスト名の TXTレコード(SPF) に追加登録
# 注意
# ・セットアップ後、サーバを再起動します
# @sacloud-desc-end
#
# @sacloud-require-archive distro-centos distro-ver-7
# @sacloud-textarea required heredoc DOMAIN "Fromに使用するドメイン" ex="example.com"
# @sacloud-text SELECTOR "DKIMのセレクタ" ex="default"
# @sacloud-textarea heredoc DKIMKEY "DKIMの署名に使用する秘密鍵" ex="-----BEGIN PRIVATE KEY-----から入力"
# @sacloud-textarea required heredoc IPADDRESS "接続を許可するIPアドレス" ex="127.0.0.1"

_motd() {
	LOG=$(ls /root/.sacloud-api/notes/*log)
	case $1 in
		start)
			echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
		;;
		fail)
			echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
			exit 1
		;;
		end)
			cp -f /dev/null /etc/motd
		;;
	esac
}

set -ex

#-- スタートアップスクリプト開始
_motd start
trap '_motd fail' ERR

#-- tool のインストールと更新
yum install -y bind-utils
yum update -y

#-- 変数の展開
cat > domain.list @@@DOMAIN@@@
cat > ipaddress.list @@@IPADDRESS@@@
SELECTOR=@@@SELECTOR@@@
cat > dkim.key @@@DKIMKEY@@@

#-- ipaddress の取得
source /etc/sysconfig/network-scripts/ifcfg-eth0

#-- postfix の設定
for x in $(cat domain.list)
do
	if [ $(dig ${x}. mx +short | wc -l) -eq 0 ]
	then
		_motd fail
	fi

	echo "${x} OK" >> /etc/postfix/access
done

postmap /etc/postfix/access

POSTCONF="postconf -c /etc/postfix -e"
${POSTCONF} inet_interfaces=${IPADDR}
${POSTCONF} smtpd_helo_restrictions="reject_invalid_hostname reject_non_fqdn_hostname reject_unknown_hostname"
${POSTCONF} smtpd_sender_restrictions="reject_non_fqdn_sender reject_unknown_sender_domain"
${POSTCONF} inet_protocols=ipv4
${POSTCONF} smtpd_helo_required=yes
${POSTCONF} message_size_limit=52428800
${POSTCONF} disable_vrfy_command=yes
${POSTCONF} smtpd_discard_ehlo_keywords=dsn,enhancedstatuscodes,etrn
${POSTCONF} smtpd_sender_restrictions="check_sender_access hash:/etc/postfix/access, reject"
${POSTCONF} smtp_tls_loglevel=1
${POSTCONF} smtp_tls_security_level=may
${POSTCONF} smtp_use_tls=yes
${POSTCONF} smtp_tls_CAfile=/etc/pki/tls/certs/ca-bundle.crt
${POSTCONF} tls_random_source=dev:/dev/urandom

MYNETWORKS="127.0.0.1,${IPADDR}"
for x in $(cat ipaddress.list)
do
	MYNETWORKS="${MYNETWORKS},${x}"
done
MYNETWORKS=$(echo ${MYNETWORKS} | sed 's/,$//')
${POSTCONF} mynetworks=${MYNETWORKS}

#-- firewalld の設定
for x in $(cat ipaddress.list)
do
	firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${x}/32' accept"
done

#-- dkim の設定
if [ ! -z "${SELECTOR}" ]
then
	#-- dkim の設定処理を書く
	curl -s https://rspamd.com/rpm-stable/centos-7/rspamd.repo > /etc/yum.repos.d/rspamd.repo
	rpm --import https://rspamd.com/rpm-stable/gpg.key
	yum install -y rspamd redis

	mkdir /etc/rspamd/local.d/keys

	cat <<-_EOL_> /etc/rspamd/local.d/redis.conf
	servers = "127.0.0.1";
	_EOL_

	cat <<-'_EOL_'> /etc/rspamd/local.d/dkim_signing.conf
	#-- メーリングリストや転送の為の設定
	allow_hdrfrom_mismatch = true;
	sign_local = true;
	use_esld = false;
	try_fallback = false;
	auth_only = false;
	use_domain = 'header';
	sign_networks = "/etc/rspamd/local.d/dkim_signing_network.map" ;

	_EOL_

	for x in $(cat domain.list)
	do
		cp dkim.key /etc/rspamd/local.d/keys/${SELECTOR}.${x}.key
		chown _rspamd. /etc/rspamd/local.d/keys/${SELECTOR}.${x}.key

		cat <<-_EOL_>> /etc/rspamd/local.d/dkim_signing.conf
		domain {
			${x} {
				path = "/etc/rspamd/local.d/keys/\$selector.\$domain.key";
				selector = "${SELECTOR}";
			}
		}
		_EOL_

		cat <<-_EOL_>>/etc/rspamd/local.d/whitelist_sender_domain.map
		${x}
		_EOL_
	done

	cat <<-_EOL_> /etc/rspamd/local.d/history_redis.conf
	servers         = 127.0.0.1:6379;
	key_prefix      = "rs_history";
	nrows           = 10000;
	compress        = true;
	subject_privacy = false;
	_EOL_

	cat <<-'_EOL_'>/etc/rspamd/local.d/multimap.conf
	WHITELIST_SENDER_DOMAIN {
		type = "from";
		map = "/etc/rspamd/local.d/whitelist_sender_domain.map";
		filter = "email:domain";
		score = -10.0
	}
	WHITELIST_IP {
		type = "ip";
		map = "/etc/rspamd/local.d/whitelist_ip.map";
		prefilter = true;
		action = "accept";
	}
	_EOL_

	cat <<-_EOL_>/etc/rspamd/local.d/whitelist_ip.map
	${IPADDR}
	_EOL_

	for x in $(cat ipaddress.list)
	do
		cat <<-_EOL_>>/etc/rspamd/local.d/whitelist_ip.map
		${x}
		_EOL_
	
		cat <<-_EOL_>/etc/rspamd/local.d/dkim_signing_network.map
		${x}/32
		_EOL_
	
	done

	#-- redis, rspamd の有効化
	systemctl enable redis rspamd

	#-- postfix に milter の設定を追加
	${POSTCONF} milter_default_action=tempfail
	${POSTCONF} milter_protocol=6
	${POSTCONF} smtpd_milters=inet:127.0.0.1:11332
	${POSTCONF} non_smtpd_milters=inet:127.0.0.1:11332

fi

#-- dig にて spf と dkim のレコード登録確認
yum install -y python34 python34-pip
pip3.4 install py3dns pyspf

cat <<-'_EOL_'> check_spf.py
#!/usr/bin/python3.4
import sys,spf
print(spf.check(i=sys.argv[1],s=sys.argv[2],h="localhost")[0])
_EOL_
chmod 755 check_spf.py

while :
do
	FLAG=0
	MESSAGE=""

	if [ $(dig $(hostname). a +short | grep -c "^${IPADDR}$") -eq 0 ]
	then
		MESSAGE=$(echo -e "${MESSAGE}$(hostname) の A レコードが ${IPADDR} と一致していません")
		FLAG=$(($FLAG + 1))
	fi

	if [ $(dig -x ${IPADDR} +short | grep -c "^$(hostname).$") -eq 0 ]
	then
		MESSAGE=$(echo -e "${MESSAGE}${IPADDR} の PTR レコードが $(hostname) と一致していません")
		FLAG=$(($FLAG + 1))
	fi

	for x in $(cat domain.list)
	do
		if [ $(./check_spf.py ${IPADDR} ${x}) != "pass" ]
		then
			MESSAGE=$(echo -e "${MESSAGE}${IPADDR} が ${x} の SPF レコードに登録されていません")
			FLAG=$(($FLAG + 1))
		fi

		if [ ! -z "${SELECTOR}" ]
		then
			if [ $(dig ${SELECTOR}._domainkey.${x}. txt +short | wc -l) -eq 0 ]
			then
				MESSAGE=$(echo -e "${MESSAGE}${SELECTOR}._domainkey.${x}のTXTレコードがDNSに登録されていません")
				FLAG=$(($FLAG + 1))
			fi
		fi
	done

	if [ ${FLAG} -ne 0 ]
	then
		_motd start
		echo -e "${MESSAGE}" >> /etc/motd
	fi

	if [ ${FLAG} -eq 0 ]
	then
		break
	fi

	sleep 30

done

_motd end

#-- OS再起動
shutdown -r 1

