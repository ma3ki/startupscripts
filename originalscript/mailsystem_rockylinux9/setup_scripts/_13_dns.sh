#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- 逆引き追加
name=$(hostname | awk -F\. '{print $1}')
usacloud ipaddress update-host-name -y --host-name ${name}.${FIRST_DOMAIN} --ip-address ${IPADDR}
