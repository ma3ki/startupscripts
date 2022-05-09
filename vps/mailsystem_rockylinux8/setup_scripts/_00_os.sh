#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- host名設定
hostnamectl set-hostname ${HOST}

#-- pkg インストール
dnf install -y epel-release
dnf install -y bind-utils telnet jq expect bash-completion sysstat mailx git tar chrony make 
dnf config-manager --set-enabled powertools

#-- selinux 無効化
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

#-- certbot で使用する token と secret
cat <<_EOL_> ~/.sakura
dns_sakuracloud_api_token = "${SACLOUD_APIKEY_ACCESS_TOKEN}"
dns_sakuracloud_api_secret = "${SACLOUD_APIKEY_ACCESS_TOKEN_SECRET}"
_EOL_
chmod 600 ~/.sakura

#-- rsyslog の ratelimit を無効化
sed -i '/^module(load="imjournal"/a \       ratelimit.interval="0"' /etc/rsyslog.conf
