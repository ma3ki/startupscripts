#!/bin/bash
#
# @sacloud-name "MailSystem"
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトはメールサーバをセットアップします
# (このスクリプトは、CentOS7.Xでのみ動作します)
#
# 事前作業として以下の2つが必要となります
# ・さくらのクラウドDNSにメールアドレスのドメインとして使用するゾーンを登録していること
# ・さくらのクラウドAPIのアクセストークンを取得していること
# 注意
# ・ホスト名の入力はドメインを含めないこと(例: mail)
# ・使用するDNSゾーンはリソースレコードが未登録であること
# ・ローカルパートが下記のメールアドレスは自動で作成するため、入力しないこと
#   [admin root postmaster abuse nobody]
# ・セットアップ後、サーバを再起動します
# @sacloud-desc-end
#
# @sacloud-require-archive distro-centos distro-ver-7
# @sacloud-textarea required heredoc ADDR "作成するメールアドレスのリスト" ex="foo@example.com"
# @sacloud-apikey required permission=create AK "APIキー"
# @sacloud-text required MAILADDR "セットアップ完了メールを送信する宛先" ex="foobar@example.com"
# @sacloud-textarea required heredoc MLDOMAIN "作成するメーリングリストドメイン" ex="ml.example.com"

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
yum install -y epel-release
yum install -y bind-utils telnet jq expect bash-completion sysstat mailx git
yum update -y

#-- usacloud のインストール
curl -fsSL http://releases.usacloud.jp/usacloud/repos/setup-yum.sh | sh
zone=$(dmidecode -t system | awk '/Family/{print $NF}')

set +x

#-- usacloud の設定
usacloud config --token ${SACLOUD_APIKEY_ACCESS_TOKEN}
usacloud config --secret ${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}
usacloud config --zone ${zone}

#-- certbot で使用する token と secret の設定
cat <<_EOL_> ~/.sakura
dns_sakuracloud_api_token = "${SACLOUD_APIKEY_ACCESS_TOKEN}"
dns_sakuracloud_api_secret = "${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"
_EOL_
chmod 600 ~/.sakura

set -x

#-- セットアップスクリプトをダウンロード
git clone https://github.com/ma3ki/startupscripts.git
cd startupscripts/publicscript/mailsystem2
source config.source

#-- 特殊タグの展開
mkdir -p ${WORKDIR}
addr_list=${WORKDIR}/address.list
cat > ${addr_list} @@@ADDR@@@
mldomain_list=${WORKDIR}/mldomain.list
cat > ${mldomain_list} @@@MLDOMAIN@@@
mail_addr="@@@MAILADDR@@@"
pass_list=${WORKDIR}/password.list

#-- ドメイン、アドレス情報の取得
domain_list="$(awk -F@ '{print $2}' ${addr_list} | sort | uniq | tr '\n' ' ' | sed 's/ $//')"
mldomain_list="sort ${mldomain_list} | uniq | tr '\n' ' ' | sed 's/ $//')"
first_address=$(egrep -v "^$|^#" ${addr_list} | grep '@' | head -1 )
first_domain=$(echo ${first_address} | awk -F@ '{print $2}' )

#-- ipaddress の取得
source /etc/sysconfig/network-scripts/ifcfg-eth0

#-- セットアップ設定ファイルの修正
rpassword=$(mkpasswd -l 12 -d 3 -c 3 -C 3 -s 0)
sed -i -e "s/^DOMAIN_LIST=.*/DOMAIN_LIST=\"${domain_list}\"/" \
  -e "s/^MLDOMAIN_LIST=.*/MLDOMAIN_LIST=\"${mldomain_list}\"/" \
  -e "s/^ML_MASTER=.*/ML_MASTER=\"admin@${first_domain}\"/" \
  -e "s/^FIRST_DOMAIN=.*/FIRST_DOMAIN=\"${first_domain}\"/" \
  -e "s/^FIRST_ADDRESS=.*/FIRST_ADDRESS=\"${first_address}\"/" \
  -e "s/^ROOT_PASSWORD=.*/ROOT_PASSWORD=${rpassword}/" \
  -e "s/^IPADDR=.*/IPADDR=${IPADDR}/" config.source

_motd end

# reboot
# shutdown -r 1
