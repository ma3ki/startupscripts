#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

if [ "${MLDOMAIN_LIST}x" = "x" ]
then
  exit 0
fi

#-- リポジトリの設定と sympa のインストール
curl -o /etc/yum.repos.d/sympa-ja.org.rhel.repo http://sympa-ja.org/download/rhel/sympa-ja.org.rhel.repo
yum install -y sympa sympa-nginx

#-- sympa の database を作成
export HOME=/root
mysql -e "CREATE DATABASE sympa CHARACTER SET utf8;"
mysql -e "GRANT ALL PRIVILEGES ON sympa.* TO 'sympa'@'localhost' IDENTIFIED BY 'sympass';"

cp -p /etc/sympa/sympa.conf{,.org}

sed -i -e "/^#domain/a domain ${FIRST_DOMAIN}" \
       -e "/^#listmaster/a listmaster admin@${FIRST_MASTER}" \
       -e "/^#lang/a lang ja" \
       -e "/^#db_type/a db_type MySQL" \
       -e "/^#db_name/a db_name sympa" \
       -e "/^#db_host/a db_host 127.0.0.1" \
       -e "/^#db_user/a db_user sympa" \
       -e "/^#db_passwd/a db_passwd sympass" \
       -e "/^#wwsympa_url/a wwsympa_url https://${FIRST_DOMAIN}/sympa" /etc/sympa/sympa.conf

for x in ${MLDOMAIN_LIST}
do
  mkdir -p /etc/sympa/${x}
  echo "wwsympa_url https://${FIRST_DOMAIN}/sympa/${x}"
  chown -R sympa. /etc/sympa/${x}
done

#- sympa の設定の確認(何も表示されなければOK)
sympa.pl --health_check

#- 定期的に postfix の設定を更新するスクリプトを作成
cat <<'_EOF_'> /usr/local/bin/create_sympa_regex.sh
#!/bin/bash

if [ $# -ne 1 ]
then
  echo "usage: $0 <sympa-domain>"
  exit 1
fi

DOMAIN=$1
SYMPA1=/etc/sympa/aliases.sympa.postfix
SYMPA2=/var/lib/sympa/sympa_aliases
REGEX=/etc/postfix-inbound/symparcptcheck.regexp
TMP=/tmp/symparcptcheck.regexp

# 2分以内にメーリングリストの更新があったらpostfixに反映する
LIMIT=120

if [ $(($(stat --format=%Y ${SYMPA1}) + ${LIMIT})) -ge $(date +%s) ] || [ $(($(stat --format=%Y ${SYMPA2}) + ${LIMIT})) -ge $(date +%s) ]
then
  /usr/bin/cp /dev/null ${TMP}
  for x in $(awk -F: '!/^#/{print $1}' ${SYMPA1} ${SYMPA2})
  do
      echo "/^${x}@${DOMAIN}/ OK" >> ${TMP}
  done
  /usr/bin/mv -f ${TMP} ${REGEX}
  systemctl reload postfix
fi

exit 0
_EOF_

chmod 755 /usr/local/bin/create_sympa_regex.sh

#- alias 関連ファイルのパーミション設定やデータ更新
chown sympa /etc/sympa/aliases.sympa.postfix.db
chown sympa /var/lib/sympa
postalias /var/lib/sympa/sympa_aliases

sed -i -e "s/\S*@my.domain.org/admin@${FIRST_DOMAIN}/" -e "s/postmaster/admin@${FIRST_DOMAIN}/" /etc/sympa/aliases.sympa.postfix
postalias /etc/sympa/aliases.sympa.postfix

for x in ${MLDOMAIN_LIST}
do
  #- postfix 用の宛先存在確認ルールを作成(上記コマンド実行後、２分以内に実行すること)
  /usr/local/bin/create_sympa_regex.sh ${x}

  #- sympaでメーリングリストが追加された場合にpostfixに設定を反映するためのcron
  echo "* * * * * root /usr/local/bin/create_sympa_regex.sh ${x} >/dev/null 2>&1" >> /etc/cron.d/startup-script-cron
done

#-- nginx に設定追加
rm -f /etc/nginx/conf.d/sympa.conf
cat <<'_EOF_'> /etc/nginx/conf.d/https.d/sympa.conf
    location ~ ^/sympa/.* {
        include       /etc/nginx/fastcgi_params;
        fastcgi_pass  unix:/var/run/sympa/wwsympa.socket;

        # If you changed wwsympa_url in sympa.conf, change this regex too!
        fastcgi_split_path_info ^(/sympa)(.*)$;
        fastcgi_param SCRIPT_FILENAME /usr/libexec/sympa/wwsympa.fcgi;
        fastcgi_param PATH_INFO $fastcgi_path_info;

    }

    location /static-sympa/css {
        alias /var/lib/sympa/css;
    }
    location /static-sympa/pictures {
        alias /var/lib/sympa/pictures;
    }
    location /static-sympa {
        alias /usr/share/sympa/static_content;
    }
_EOF_

systemctl restart nginx

#-- sympa 起動
systemctl enable sympa wwsympa
systemctl start sympa wwsympa

#-- sympa を mysql 起動後に起動するように設定
sed -i "s/^After=syslog.target/After=syslog.target mysqld.service/" /usr/lib/systemd/system/sympa.service
systemctl daemon-reload

#-- postfix の設定
#- メールを受け付ける対象にml用ドメインを追加
#- ml用ドメインはローカルに配送する(alias を適用する)設定を追加
for x in ${MLDOMAIN_LIST}
do
  echo "${x}" >> /etc/postfix-inbound/relay_domains
  echo "${x} local:" >> /etc/postfix-inbound/transport
done

postmap /etc/postfix-inbound/transport

#- alias を sympa のファイルを参照するように変更、宛先チェックなどの設定も変更
postconf -c /etc/postfix-inbound -e alias_maps=hash:/etc/sympa/aliases.sympa.postfix,hash:/var/lib/sympa/sympa_aliases
postconf -c /etc/postfix-inbound -e alias_database=/etc/sympa/aliases.sympa.postfix,hash:/var/lib/sympa/sympa_aliases
postconf -c /etc/postfix-inbound -e smtpd_recipient_restrictions="check_recipient_access ldap:/etc/postfix-inbound/ldaprcptcheck.cf check_recipient_access regexp:/etc/postfix-inbound/symparcptcheck.regexp reject"
postconf -c /etc/postfix-inbound -e transport_maps="ldap:/etc/postfix-inbound/ldaptransport.cf hash:/etc/postfix-inbound/transport"

systemctl restart postfix

#-- rspamd の設定

#- envelope from が ml用ドメインの場合、SPAM判定のScoreを10下げる(これを実施しないと送信時にX-Spam: Yes が追加される)
cat <<_EOF_> /etc/rspamd/local.d/multimap.conf
WHITELIST_SENDER_DOMAIN {
  type = "from";
  filter = "email:domain";
  map = "/etc/rspamd/local.d/whitelist_sender_domain.map";
  score = -10.0
}
_EOF_

for x in ${MLDOMAIN_LIST}
do
  echo "${x}" >> /etc/rspamd/local.d/whitelist_sender_domain.map
done

#- rspamd 再起動
systemctl restart rspamd

