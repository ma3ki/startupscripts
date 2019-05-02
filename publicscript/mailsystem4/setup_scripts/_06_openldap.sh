#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- openldap のインストール
yum install -y openldap-servers openldap-clients sendmail-cf

#-- DBの設定
cat <<'_EOL_'> /var/lib/ldap/DB_CONFIG
set_cachesize 0 10485760 1
set_flags DB_LOG_AUTOREMOVE
set_lg_regionmax 262144
set_lg_bsize 2097152
_EOL_

root_pw=$(slappasswd -s ${ROOT_PASSWORD})

#-- sendmail schema を保存
cp -p /usr/share/sendmail-cf/sendmail.schema /etc/openldap/schema/

#-- slapd.conf を作成
cat <<_EOL_> /etc/openldap/slapd.conf
loglevel 0x4100
sizelimit -1
include  /etc/openldap/schema/corba.schema
include  /etc/openldap/schema/core.schema
include  /etc/openldap/schema/cosine.schema
include  /etc/openldap/schema/duaconf.schema
include  /etc/openldap/schema/dyngroup.schema
include  /etc/openldap/schema/inetorgperson.schema
include  /etc/openldap/schema/java.schema
include  /etc/openldap/schema/misc.schema
include  /etc/openldap/schema/nis.schema
include  /etc/openldap/schema/openldap.schema
include  /etc/openldap/schema/ppolicy.schema
include  /etc/openldap/schema/collective.schema
include  /etc/openldap/schema/sendmail.schema
allow bind_v2
pidfile  /var/run/openldap/slapd.pid
argsfile /var/run/openldap/slapd.args
moduleload syncprov.la
access to attrs=UserPassword
    by dn="${ROOT_DN}" write
    by self write
    by anonymous auth
    by * none
access to dn.regex="uid=.*,ou=Termed,dc=.*"
    by * none
access to *
    by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage
    by * read
database monitor
access to *
    by dn.exact="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read
    by dn.exact="${ROOT_DN}" read
    by * none
database bdb
suffix  ""
checkpoint 1024 15
rootdn  "${ROOT_DN}"
rootpw  "${root_pw}"
directory /var/lib/ldap
index objectClass   eq,pres
index uid           eq,pres,sub
index mailHost,mailRoutingAddress,mailLocalAddress,userPassword,sendmailMTAHost eq,pres
_EOL_

#-- slapd の起動オプションの変更
sed -i "s#^SLAPD_URLS=.*#SLAPD_URLS=\"ldap://${LDAP_MASTER}/\"#" /etc/sysconfig/slapd
mv /etc/openldap/slapd.d /etc/openldap/slapd.d.org

#-- yum update で slapd.d が復活すると起動しないので定期的に確認して対応
cat <<_EOL_>> ${CRONFILE}
* * * * * root rm -rf /etc/openldap/slapd.d >/dev/null 2>&1
* * * * * root /usr/bin/mv -f /etc/openldap/slapd.conf{.bak,} >/dev/null 2>&1
_EOL_

#-- rsyslog に slapd のログ出力設定を追加
echo "local4.*  /var/log/openldaplog" > /etc/rsyslog.d/openldap.conf
sed -i '1s#^#/var/log/openldaplog\n#' /etc/logrotate.d/syslog
systemctl restart rsyslog

#-- slapd の起動
systemctl enable slapd
systemctl start slapd

#-- ドメインの登録
$(dirname $0)/../tools/create_domain.sh
