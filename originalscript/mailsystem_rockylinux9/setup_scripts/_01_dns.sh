#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

name=$(hostname | awk -F\. '{print $1}')

#-- ホスト名の設定
hostnamectl set-hostname ${name}.${FIRST_DOMAIN}

#-- DNSレコードの登録
for domain in ${DOMAIN_LIST}
do

  if [ "${domain}" = "${FIRST_DOMAIN}" ]
  then
cat <<_EOF_> ${domain}.json
{"Records": [
    { "Name": "@", "Type": "A", "RData": "${IPADDR}", "TTL": 600 },
    { "Name": "@", "Type": "MX", "RData": "10 ${FIRST_DOMAIN}.", "TTL": 600 },
    { "Name": "@", "Type": "TXT", "RData": "v=spf1 +ip4:${IPADDR} -all", "TTL": 600 },
    { "Name": "_dmarc", "Type": "TXT", "RData": "v=DMARC1; p=reject; rua=mailto:dmarc-report@${domain}", "TTL": 600 },
    { "Name": "${name}", "Type": "A", "RData": "${IPADDR}", "TTL": 600 },
    { "Name": "@", "Type": "HTTPS", "RData": "10 . alpn=h3,h2", "TTL": 600 },
    { "Name": "autoconfig", "Type": "A", "RData": "${IPADDR}", "TTL": 600 }
]}
_EOF_
  else
cat <<_EOF_> ${domain}.json
{"Records": [
    { "Name": "@", "Type": "A", "RData": "${IPADDR}", "TTL": 600 },
    { "Name": "@", "Type": "MX", "RData": "10 ${FIRST_DOMAIN}.", "TTL": 600 },
    { "Name": "@", "Type": "TXT", "RData": "v=spf1 +ip4:${IPADDR} -all", "TTL": 600 },
    { "Name": "_dmarc", "Type": "TXT", "RData": "v=DMARC1; p=reject; rua=mailto:dmarc-report@${domain}", "TTL": 600 },
    { "Name": "autoconfig", "Type": "CNAME", "RData": "autoconfig.${FIRST_DOMAIN}.", "TTL": 600 }
]}
_EOF_
  fi
  usacloud dns update ${domain} -y --parameters ${domain}.json
done

