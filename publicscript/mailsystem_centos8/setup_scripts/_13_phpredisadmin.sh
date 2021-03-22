#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

mkdir -p ${WORKDIR}/git
git clone https://github.com/ErikDubbelboer/phpRedisAdmin.git ${WORKDIR}/git/phpredisadmin

cd ${WORKDIR}/git/phpredisadmin
version=$(git tag | sort --version-sort | tail -1)
git checkout ${version}

cp -pr ${WORKDIR}/git/phpredisadmin ${HTTPS_DOCROOT}/phpredisadmin-${version}
ln -s ${HTTPS_DOCROOT}/phpredisadmin-${version} ${HTTPS_DOCROOT}/phpredisadmin
cp -p ${HTTPS_DOCROOT}/phpredisadmin/includes/config.{sample.inc.php,inc.php}
chown -R nginx. ${HTTPS_DOCROOT}/phpredisadmin-${version}

tail2=$(tail -2 ${HTTPS_DOCROOT}/phpredisadmin/includes/config.inc.php | head -1)
tail1=$(tail -1 ${HTTPS_DOCROOT}/phpredisadmin/includes/config.inc.php)
sed -i '$d' ${HTTPS_DOCROOT}/phpredisadmin/includes/config.inc.php
sed -i '$d' ${HTTPS_DOCROOT}/phpredisadmin/includes/config.inc.php

cat <<_EOL_>> ${HTTPS_DOCROOT}/phpredisadmin/includes/config.inc.php
${tail2},
  //enable HTTP authentication
  'login' => array(
    // Username => Password
    // Multiple combinations can be used
    'admin' => array(
      'password' => 'root_password',
    ),
    'guest' => array(
      'password' => 'root_password',
      'servers'  => array(1) // Optional list of servers this user can access.
    )
  )
${tail1}
_EOL_

sed -i -e "s/root_password/${ROOT_PASSWORD}/" ${HTTPS_DOCROOT}/phpredisadmin/includes/config.inc.php
