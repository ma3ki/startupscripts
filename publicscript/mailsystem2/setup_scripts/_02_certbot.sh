#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

domain=${FIRST_DOMAIN}

#-- certbot のインストール
yum install -y certbot certbot-dns-sakuracloud

#-- wildcard 証明書のインストール
certbot certonly --dns-sakuracloud \
  --dns-sakuracloud-credentials ~/.sakura \
  --dns-sakuracloud-propagation-seconds 60 \
  -d *.${domain} -d ${domain} \
  -m admin@${domain} \
  --manual-public-ip-logging-ok \
  --agree-tos

#-- cron に証明書の更新処理を設定
echo "$((${RANDOM}%60)) $((${RANDOM}%24)) * * $((${RANDOM}%7)) root certbot renew --post-hook 'systemctl reload nginx postfix'" > /etc/cron.d/certbot-auto


