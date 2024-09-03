#!/bin/bash -e
#
# ./add_domain_config.sh <domain>

source $(dirname $0)/../config.source
echo "---- $0 ----"

domain=$1

#-- rspamd
rspamadm dkim_keygen -d ${domain} -s ${SELECTOR} -b 2048 > ${WORKDIR}/keys/${domain}.keys
head -28 ${WORKDIR}/keys/${domain}.keys > /etc/rspamd/local.d/keys/${SELECTOR}.${domain}.key
chmod 600 /etc/rspamd/local.d/keys/${SELECTOR}.${domain}.key
chown _rspamd. /etc/rspamd/local.d/keys/${SELECTOR}.${domain}.key

cat <<_EOL_>> /etc/rspamd/local.d/dkim_selectors.map
${domain} ${SELECTOR}
_EOL_

cat <<_EOL_>> /etc/rspamd/local.d/dkim_paths.map
${domain} /etc/rspamd/local.d/keys/\$selector.\$domain.key
_EOL_

systemctl restart rspamd

#-- DNS
record=$(cat ${WORKDIR}/keys/${domain}.keys | tr -d '[\n\t]' | sed -e 's/"//g' -e 's/.* TXT ( //' -e 's/) ; $//')
cat <<_EOF_> ${domain}.json
{"Records": [
    { "Name": "@", "Type": "A", "RData": "${IPADDR}", "TTL": 600 },
    { "Name": "@", "Type": "MX", "RData": "10 ${FIRST_DOMAIN}.", "TTL": 600 },
    { "Name": "@", "Type": "TXT", "RData": "v=spf1 +ip4:${IPADDR} -all", "TTL": 600 },
    { "Name": "_dmarc", "Type": "TXT", "RData": "v=DMARC1; p=reject; rua=mailto:dmarc-report@${domain}", "TTL": 600 },
    { "Name": "${SELECTOR}._domainkey", "Type": "TXT", "RData": "${record}", "TTL": 600 },
    { "Name": "autoconfig", "Type": "CNAME", "RData": "autoconfig.${FIRST_DOMAIN}.", "TTL": 600 }
]}
_EOF_
usacloud dns update ${domain} -y --parameters ${domain}.json

#-- dovecot
cat <<_EOL_>>/etc/dovecot/local.conf
userdb {
  args = /etc/dovecot/dovecot-ldap_${domain}.conf.ext
  driver = ldap
}
_EOL_

base=$(printf ${domain} | xargs -d "." -i printf "dc={}," | sed 's/,$//')

cat <<_EOL_>/etc/dovecot/dovecot-ldap_${domain}.conf.ext
hosts = ${LDAP_SERVER}
auth_bind = yes
base = ${base}
pass_attrs=mailRoutingAddress=User,userPassword=password
pass_filter = (mailRoutingAddress=%u)
user_attrs = \
  =uid=dovecot, \
  =gid=dovecot, \
  =mail=maildir:/var/dovecot/%Ld/%Ln, \
  =home=/var/dovecot/%Ld/%Ln, \
  mailQuota=quota_rule=*:bytes=%\$
user_filter = (mailRoutingAddress=%u)
iterate_attrs = mailRoutingAddress=user
iterate_filter = (mailRoutingAddress=*)
_EOL_

systemctl restart dovecot

#-- postfix
cat <<_EOL_>>/etc/postfix-inbound/relay_domains
${domain}
_EOL_

systemctl restart postfix

#-- phpldapadmin
ARRAY_LIST=$(for tmpdom in ${DOMAIN_LIST} ${domain}
do
  base=$(printf ${tmpdom} | xargs -d "." -i printf "dc={}," | sed -e 's/,$//' -e "s/^/'/" -e "s/$/'/")
  printf "${base},"
done | sed 's/,$//')

sed -i "337 s/^\$servers.*/\$servers->setValue('server','base',array(${ARRAY_LIST}));/" /etc/phpldapadmin/config.php
