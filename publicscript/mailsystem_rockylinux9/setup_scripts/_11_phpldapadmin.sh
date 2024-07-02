#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

dnf install -y phpldapadmin

ln -s /usr/share/phpldapadmin /var/www/html/https_root/phpldapadmin
chgrp nginx /etc/phpldapadmin/config.php

cd /etc/phpldapadmin
cp -p config.php config.php.org

#-- 複数ドメインがある場合は、カンマ区切りで追加する
ARRAY_LIST=$(for domain in ${DOMAIN_LIST}
do
  tmpdc=""
  for dc in $(echo "${domain}" | sed 's/\./ /g')
  do
    tmpdc="${tmpdc}dc=${dc},"
  done
  dc=$(echo ${tmpdc} | sed -e 's/,$//' -e "s/^/'/" -e "s/$/'/")
  printf "${dc},"
done | sed 's/,$//')

cp -p /etc/phpldapadmin/config.php /etc/phpldapadmin/config.php.org
sed -i -e "585i \$servers->setValue('unique','attrs',array('mail','uidNumber','mailRoutingaddress','mailAlternateAddress'));" \
  -e "525i \$servers->setValue('login','anon_bind',false);" \
  -e "s/\$servers->setValue('login','attr','uid');/\$servers->setValue('login','attr','dn');/" \
  -e "336i \$servers->setValue('server','base',array(${ARRAY_LIST}));" \
  -e "62i \$config->custom->appearance['language'] = 'auto';"  /etc/phpldapadmin/config.php

#-- 使用しないテンプレートを移動
mkdir ${HTTPS_DOCROOT}/phpldapadmin/templates/creation_backup
for x in courierMailAccount.xml courierMailAlias.xml mozillaOrgPerson.xml sambaDomain.xml sambaGroupMapping.xml sambaMachine.xml sambaSamAccount.xml dNSDomain.xml
do
  mv ${HTTPS_DOCROOT}/phpldapadmin/templates/creation/${x} ${HTTPS_DOCROOT}/phpldapadmin/templates/creation_backup
done
