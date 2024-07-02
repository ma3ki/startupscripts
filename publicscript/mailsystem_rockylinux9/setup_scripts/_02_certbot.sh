#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- certbot のインストール
dnf install -y certbot python3-certbot-dns-sakuracloud

#-- wildcard 証明書のインストール
expect -c "
set timeout 180
spawn certbot certonly --dns-sakuracloud --dns-sakuracloud-credentials /root/.sakura --dns-sakuracloud-propagation-seconds 90 -d *.${FIRST_DOMAIN} -d ${FIRST_DOMAIN} -m admin@${FIRST_DOMAIN} --agree-tos
expect \"(Y)es/(N)o:\"
send -- \"Y\n\"
expect \"Congratulations\"
"

#-- 証明書が作成されたことを確認
ls -l /etc/letsencrypt/live/${FIRST_DOMAIN}/fullchain.pem

#-- cron に証明書の更新処理を設定
echo "$((${RANDOM}%60)) $((${RANDOM}%24)) * * $((${RANDOM}%7)) root certbot renew --post-hook 'systemctl reload nginx postfix'" >> ${CRONFILE}
