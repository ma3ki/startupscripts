#!/bin/bash -x

# @sacloud-name "zabbix-server"
# @sacloud-once
# @sacloud-desc-begin
#   さくらのクラウド上で Zabbix Server 7.0 を 自動的にセットアップするスクリプトです
#   このスクリプトは、RockyLinux 9.X でのみ動作します
#   セットアップには5分程度時間がかかります
#
#   URL http://サーバのIPアドレス/zabbix/
#   デフォルトのログイン情報 ユーザー名: Admin, パスワード: zabbix
# @sacloud-desc-end
#
# @sacloud-select-end
# @sacloud-password ZP "Zabbix WebのAdminアカウントのパスワード変更"
# @sacloud-require-archive distro-rocky distro-ver-9.*

#---------UPDATE /etc/motd----------#
_motd() {
	log=$(ls /root/.sacloud-api/notes/*log)
	case $1 in
	start)
		echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the logfile: ${log}\n" > /etc/motd
	;;
	fail)
		echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the logfile: ${log}\n" > /etc/motd
	;;
	end)
		cp -f /dev/null /etc/motd
	;;
	esac
}

set -e
trap '_motd fail' ERR

_motd start

#---------SET sacloud values---------#
ZABBIX_PASSWORD=@@@ZP@@@
ZABBIX_VERSION=7.0

#---------START OF mysql-server---------#
dnf -y install mysql-server expect
systemctl enable mysqld
systemctl start mysqld

PASSWORD=$(mkpasswd-expect -l 12 -d 3 -c 3 -C 3 -s 0)

(mysqld --initialize-insecure || true)
mysqladmin -u root password "${PASSWORD}"

cat <<_EOL_> /root/.my.cnf
[client]
host     = localhost
user     = root
password = ${PASSWORD}
socket   = /var/lib/mysql/mysql.sock
_EOL_
chmod 600 /root/.my.cnf
export HOME=/root

#-- validate_passwordのコンポーネントをインストール
mysql --user=root --password=${PASSWORD} -e "INSTALL COMPONENT 'file://component_validate_password';"

cat <<_EOL_>> /etc/my.cnf.d/mysql-server.cnf

default_authentication_plugin=mysql_native_password
default_password_lifetime=0
validate_password.length=4
validate_password.mixed_case_count=0
validate_password.number_count=0
validate_password.special_char_count=0
validate_password.policy=LOW
log-bin-trust-function-creators=1
_EOL_

systemctl restart mysqld
mysql -e "create database zabbix character set utf8 collate utf8_bin;"
mysql -e "create user zabbix@localhost identified by 'zabbix';"
mysql -e "grant all privileges on zabbix.* to zabbix@localhost ;"
mysql -e "flush privileges;"

#---------END OF mysql-server---------#
#---------START OF zabbix-server---------#
RPM_URL=https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/rocky/9/x86_64/zabbix-release-${ZABBIX_VERSION}-2.el9.noarch.rpm
rpm -ivh ${RPM_URL}
dnf -y --disablerepo=epel install zabbix-server-mysql zabbix-web-mysql zabbix-web-japanese zabbix-agent zabbix-get zabbix-sender zabbix-apache-conf zabbix-sql-scripts

zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -u zabbix -pzabbix zabbix
# cat /usr/share/doc/zabbix-sql-scripts/mysql/double.sql | mysql -u zabbix -pzabbix zabbix
sed -i "/^# DBPassword=/a DBPassword=zabbix" /etc/zabbix/zabbix_server.conf

systemctl enable zabbix-server zabbix-agent
systemctl start zabbix-server zabbix-agent

cat <<'_EOL_'> /etc/zabbix/web/zabbix.conf.php
<?php
// Zabbix GUI configuration file.
global $DB;

$DB['TYPE']     = 'MYSQL';
$DB['SERVER']   = 'localhost';
$DB['PORT']     = '0';
$DB['DATABASE'] = 'zabbix';
$DB['USER']     = 'zabbix';
$DB['PASSWORD'] = 'zabbix';

// Schema name. Used for IBM DB2 and PostgreSQL.
$DB['SCHEMA'] = '';

$ZBX_SERVER      = 'localhost';
$ZBX_SERVER_PORT = '10051';
$ZBX_SERVER_NAME = 'zabbix';

$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
_EOL_

mysql -uzabbix -pzabbix zabbix -e "update hosts set status=0 where host = 'Zabbix server' ;"

if [ ! -z "${ZABBIX_PASSWORD}" ]
then
    dnf install -y php
    ADMIN_PASSWORD=$(php -r "echo password_hash('${ZABBIX_PASSWORD}', PASSWORD_BCRYPT);" | sed 's/\$/\\$/g')
#	ADMIN_PASSWORD=$(printf ${ZABBIX_PASSWORD} | md5sum | awk '{print $1}')
	mysql -uzabbix -pzabbix zabbix -e "update users SET passwd='${ADMIN_PASSWORD}' WHERE username = 'Admin';"
fi

firewall-cmd --permanent --add-port=10051/tcp
firewall-cmd --permanent --add-port=10050/tcp
#---------END OF zabbix-server---------#
#---------START OF http-server---------#
sed -i 's/;date\.timezone =/date.timezone = Asia\/Tokyo/' /etc/php.ini
sed -i "s/^post_max_size.*$/post_max_size = 16M/" /etc/php.ini
sed -i "s/^max_execution_time.*$/max_execution_time = 300/" /etc/php.ini
sed -i "s/^max_input_time.*$/max_input_time = 300/" /etc/php.ini

firewall-cmd --permanent --add-port=80/tcp

systemctl enable httpd
systemctl start httpd
#---------END OF http-server---------#
#---------START OF firewalld---------#
firewall-cmd --reload
#---------END OF firewalld---------#

_motd end

