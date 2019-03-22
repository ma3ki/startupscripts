#!/bin/bash
# @sacloud-name "Redmine"
# @sacloud-once
# @sacloud-desc Redmineをインストールします。
# @sacloud-desc サーバ作成後、WebブラウザでサーバのIPアドレスにアクセスしてください。
# @sacloud-desc http://サーバのIPアドレス/
# @sacloud-desc ※ セットアップには20分程度時間がかかります。
# @sacloud-desc （このスクリプトは、CentOS6.X, CetnOS7.X でのみ動作します）
# @sacloud-require-archive distro-centos distro-ver-6.*
# @sacloud-require-archive distro-centos distro-ver-7.*

function _motd() {
	LOG=$(ls /root/.sacloud-api/notes/*log)
	case $1 in
		start)
			echo -e "\n#-- Startup-script is \\033[0;32mrunning\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
		;;
		fail)
			echo -e "\n#-- Startup-script \\033[0;31mfailed\\033[0;39m. --#\n\nPlease check the log file: ${LOG}\n" > /etc/motd
			exit 1
		;;
		end)
			cp -f /dev/null /etc/motd
		;;
	esac
}

set -ex

function centos6(){
	_motd start
	trap '_motd fail' ERR

	cat <<-'EOT' > /etc/sysconfig/iptables
	*filter
	:INPUT DROP [0:0]
	:FORWARD DROP [0:0]
	:OUTPUT ACCEPT [0:0]
	:fail2ban-SSH - [0:0]
	-A INPUT -p tcp -m multiport --dports 22 -j fail2ban-SSH
	-A INPUT -p TCP -m state --state NEW ! --syn -j DROP
	-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	-A INPUT -p icmp -j ACCEPT
	-A INPUT -i lo -j ACCEPT
	-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
	-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
	-A INPUT -p udp --sport 123 --dport 123 -j ACCEPT
	-A INPUT -p udp --sport 53 -j ACCEPT
	-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
	-A fail2ban-SSH -j RETURN
	COMMIT
	EOT
	service iptables restart

	set +e
	gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
	if [ "$?" != "0" ] ; then
		command curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
		command curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -
	fi
	set -e

	echo 'gem: --no-rdoc --no-ri' > /etc/gemrc

	yum clean all
	yum -y install readline-devel zlib-devel libyaml-devel libyaml openssl-devel libxml2-devel libxslt libxslt-devel libcurl-devel sqlite-devel
	curl -L https://get.rvm.io | bash -s stable --ignore-dotfiles --autolibs=0
	set +e
	source /usr/local/rvm/scripts/rvm
	set -e
	rvm install ${RUBY}
	rvm use ${RUBY}
	gem install rails --no-ri --no-rdoc

	yum -y install expect httpd-devel mod_ssl mysql-server
	service httpd status >/dev/null 2>&1 || service httpd start
	chkconfig httpd on

	yum -y install expect httpd-devel mod_ssl postgresql-server postgresql-devel
	rpm -ivh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
	yum install --enablerepo=remi -y ImageMagick6 ImageMagick6-devel

	PASSWORD=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)

	export PGSETUP_INITDB_OPTIONS="--encoding=UTF-8 --no-locale"
	service postgresql initdb
	cp /var/lib/pgsql/data/pg_hba.conf{,.org}
	sed -i "s/ident$/trust/" /var/lib/pgsql/data/pg_hba.conf
	chkconfig postgresql on
	service postgresql start

	su - postgres -c "psql <<-_EOL_
	CREATE ROLE redmine LOGIN ENCRYPTED PASSWORD '${PASSWORD}' NOINHERIT VALID UNTIL 'infinity';
	CREATE DATABASE redmine WITH ENCODING='UTF8' OWNER=redmine;
	_EOL_
	"

	svn co http://svn.redmine.org/redmine/branches/${REDMINE} /var/lib/redmine

	cat <<- EOT > /var/lib/redmine/config/database.yml
	production:
	  adapter: postgresql
	  database: redmine
	  host: localhost
	  username: redmine
	  password: $PASSWORD
	  encoding: utf8
	EOT

	cd /var/lib/redmine
	gem install json
	bundle install --without development test
	bundle exec rake generate_secret_token
	RAILS_ENV=production bundle exec rake db:migrate

	gem install passenger
	passenger-install-apache2-module -a
	passenger-install-apache2-module --snippet > /etc/httpd/conf.d/passenger.conf
	chown -R apache:apache /var/lib/redmine
	echo 'DocumentRoot "/var/lib/redmine/public"' > /etc/httpd/conf/redmine.conf
	echo "Include conf/redmine.conf" >> /etc/httpd/conf/httpd.conf
	service httpd restart

	_motd end
	set +e

}

function centos7(){
	_motd start
	trap '_motd fail' ERR

	firewall-cmd --add-service=http --zone=public --permanent
	firewall-cmd --add-service=https --zone=public --permanent
	firewall-cmd --reload

	set +e
	gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
	if [ "$?" != "0" ] ; then
		command curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
		command curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -
	fi
	set -e

	echo 'gem: --no-rdoc --no-ri' > /etc/gemrc

	yum clean all
	yum -y install readline-devel zlib-devel libyaml-devel libyaml openssl-devel libxml2-devel libxslt libxslt-devel libcurl-devel sqlite-devel
	curl -L https://get.rvm.io | bash -s stable --ignore-dotfiles --autolibs=0
	set +e
	source /usr/local/rvm/scripts/rvm
	set -e
	rvm install ${RUBY}
	rvm use ${RUBY}
	gem install rails --no-ri --no-rdoc

	yum -y install expect httpd-devel mod_ssl postgresql-server postgresql-devel ImageMagick-devel

	PASSWORD=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)

	export PGSETUP_INITDB_OPTIONS="--encoding=UTF-8 --no-locale"
	postgresql-setup initdb
	cp /var/lib/pgsql/data/pg_hba.conf{,.org}
	sed -i "s/ident$/trust/" /var/lib/pgsql/data/pg_hba.conf
	systemctl enable postgresql
	systemctl start postgresql

	su - postgres -c "psql <<-_EOL_
	CREATE ROLE redmine LOGIN ENCRYPTED PASSWORD '${PASSWORD}' NOINHERIT VALID UNTIL 'infinity';
	CREATE DATABASE redmine WITH ENCODING='UTF8' OWNER=redmine;
	_EOL_
	"
	
	svn co http://svn.redmine.org/redmine/branches/${REDMINE} /var/lib/redmine

	cat <<- EOT > /var/lib/redmine/config/database.yml
	production:
	  adapter: postgresql
	  database: redmine
	  host: localhost
	  username: redmine
	  password: $PASSWORD
	  encoding: utf8
	EOT

	cd /var/lib/redmine
	gem install json
	bundle install --without development test
	bundle exec rake generate_secret_token
	RAILS_ENV=production bundle exec rake db:migrate

	cat <<- EOF > /etc/httpd/conf/redmine.conf
	DocumentRoot "/var/lib/redmine/public"
	<Directory "/var/lib/redmine/public">
	  Require all granted
	</Directory>
	EOF

	gem install passenger --no-rdoc --no-ri
	passenger-install-apache2-module -a
	passenger-install-apache2-module --snippet > /etc/httpd/conf.d/passenger.conf
	chown -R apache:apache /var/lib/redmine
	echo "Include conf/redmine.conf" >> /etc/httpd/conf/httpd.conf

	systemctl status httpd.service >/dev/null 2>&1 || systemctl start httpd.service
	systemctl enable httpd.service

	_motd end
	set +e

}

### main ###

VERSION=$(rpm -q centos-release --qf "%{VERSION}")
RUBY=ruby-2.5.5
REDMINE=4.0-stable

[ "$VERSION" = "6" ] && centos6
[ "$VERSION" = "7" ] && centos7

shutdown -r 1
