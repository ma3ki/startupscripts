#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

name=$(hostname | awk -F\. '{print $1}')
hostnamectl set-hostname ${name}.${FIRST_DOMAIN}

for domain in ${DOMAIN_LIST}
do
  usacloud dns record-add -y --name @ --type A   --ttl 600 --value ${IPADDR} ${domain}
  usacloud dns record-add -y --name @ --type MX  --ttl 600 --value ${FIRST_DOMAIN}. ${domain}
  usacloud dns record-add -y --name @ --type TXT --ttl 600 --value "v=spf +ip4:${IPADDR} -all" ${domain}
  usacloud dns record-add -y --name ${name} --type A       --value ${IPADDR} ${domain}
  usacloud dns record-add -y --name _dmarc --type TXT      --value "v=DMARC1; p=reject; rua=mailto:dmarc-report@${domain}" ${domain}
  usacloud dns record-add -y --name _adsp._domainkey --type TXT --value "dkim=discardable" ${domain}
  usacloud dns record-add -y --name autoconfig --type CNAME --value ${FIRST_DOMAIN}. ${domain}
done

for mldomain in ${MLDOMAIN_LIST}
do
  domain=$(echo ${mldomain} | sed 's/\w\+\.//')
  name=$(echo ${mldomain} | awk -F\. '{print $1}')
  usacloud dns record-add -y --name ${name} --type MX  --ttl 600 --value ${FIRST_DOMAIN}. ${domain}
  usacloud dns record-add -y --name ${name} --type TXT --ttl 600 --value "v=spf +ip4:${IPADDR} -all" ${domain}
  usacloud dns record-add -y --name _dmarc.${name} --type TXT    --value "v=DMARC1; p=none: rua=mailto:root@${domain}" ${domain}
  usacloud dns record-add -y --name _adsp._domainkey.${name} --type TXT --value "dkim=unknown" ${domain}
done
