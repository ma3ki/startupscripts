#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

mkdir -p ${WORKDIR}/ldap

#-- 389ds のインストール
dnf -y module enable 389-ds
dnf -y install 389-ds-base openldap-clients

#-- 389ds 設定
dscreate create-template ${WORKDIR}/ldap/389ds
sed -ri "s/;(root_dn).*/\1=${ROOT_DN}/;s/;(root_password).*/\1=${ROOT_PASSWORD}/" ${WORKDIR}/ldap/389ds
dscreate from-file ${WORKDIR}/ldap/389ds

#-- slapd の起動
systemctl enable dirsrv@localhost.service
systemctl start dirsrv@localhost

#-- ドメインの登録
sh -x $(dirname $0)/../tools/389ds_create_domain.sh
