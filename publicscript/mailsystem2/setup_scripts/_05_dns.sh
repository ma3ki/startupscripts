#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

for domain in ${DOMAIN_LIST}
do
  RECORD=$(cat ${WORKDIR}/${domain}.keys | tr '\n' ' ' | sed -e 's/.*( "//' -e 's/".*"p=/p=/' -e 's/" ).*//')
  usacloud dns record-add -y --name default._domainkey --type TXT --value "${RECORD}" ${domain}
done

for mldomain in ${ML_DOMAIN}
do
  domain=$(echo ${mldomain} | sed 's/\w\+\.//')
  name=$(echo ${mldomain} | awk -F\. '{print $1}')
  RECORD=$(cat ${WORKDIR}/${mldomain}.keys | tr '\n' ' ' | sed -e 's/.*( "//' -e 's/".*"p=/p=/' -e 's/" ).*//')
  usacloud dns record-add -y --name default._domainkey.${name} --type TXT --value "${RECORD}" ${domain}
done
