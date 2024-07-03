#!/bin/bash
#
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトは DCIMツール NetBox をセットアップします
# (CentOS7.X でのみ動作します)
# サーバ作成後はブラウザより「http://サーバのIPアドレス/」でアクセスすることができます
# @sacloud-desc-end
# @sacloud-require-archive distro-rocky distro-ver-8.*
# @sacloud-text required default=admin USERNAME "NetBox ログインユーザ" ex="admin"
# @sacloud-password required PASSWORD "NetBox ログインパスワード"
# @sacloud-text required default=root@localhost MAILADDRESS "NetBox 登録メールアドレス"

_motd() {
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

_chkvar() {
    if [ -z $2 ]
    then
        echo "$1 is not defined."
        _motd fail
    fi
}

_motd start
set -x
set -e
trap '_motd fail' ERR
source /etc/sysconfig/network-scripts/ifcfg-eth0

USERNAME="@@@USERNAME@@@"
PASSWORD="@@@PASSWORD@@@"
MADDR="@@@MAILADDRESS@@@"
_chkvar USERNAME "${USERNAME}"
_chkvar PASSWORD "${PASSWORD}"
_chkvar MADDR "${MADDR}"

# NetBoxのバージョン取得
git clone https://github.com/digitalocean/netbox.git
cd netbox
# vx.x.x
VERSION=$(git tag | sort -t\. -k 1,1 -k 2n,2 -k 3n,3 | tail -1)
cd ..

# 必要パッケージのインストール
yum update -y
yum install -y epel-release
dnf install python38 -y
echo 3 | alternatives --config python

yum install -y postgresql postgresql-server postgresql-server-devel redis expect nginx supervisor gcc libxml2-devel libxslt-devel libffi-devel graphviz openssl-devel redhat-rpm-config 
yum remove -y python3-pyyaml

####  openldap-devel 
pip3.8 install --upgrade pip

# Postgresqlのセットアップ
export PGSETUP_INITDB_OPTIONS="--encoding=UTF-8 --no-locale"
postgresql-setup --initdb --unit postgresql

cp /var/lib/pgsql/data/pg_hba.conf{,.org}
sed -i "s/ident$/md5/" /var/lib/pgsql/data/pg_hba.conf
systemctl enable postgresql redis
systemctl start postgresql redis

# NetBox 用のデータベース作成
su - postgres -c "psql <<_EOL_
CREATE DATABASE netbox;
CREATE USER netbox WITH PASSWORD 'netpass';
GRANT ALL PRIVILEGES ON DATABASE netbox TO netbox;
_EOL_
"

# NetBoxのインストールとセットアップ
curl -L -O https://github.com/digitalocean/netbox/archive/${VERSION}.tar.gz
tar -xzf ${VERSION}.tar.gz -C /opt
VNUM=$(echo ${VERSION} | sed 's/v//')
ln -s netbox-${VNUM} /opt/netbox
cd /opt/netbox
pip3.8 install -r requirements.txt
pip3.8 install napalm
pip3.8 install django-storages

pip3.8 install gunicorn
cd netbox/netbox/
SECRET=$(mkpasswd -l 50 -s 0)

sed -e "s/^ALLOWED_HOSTS.*/ALLOWED_HOSTS = [ '${IPADDR}' ]/" \
  -e "s/^    'USER': ''/    'USER': 'netbox'/" \
  -e "s/^    'PASSWORD': '', /    'PASSWORD': 'netpass', /" \
  -e "s/^SECRET_KEY.*/SECRET_KEY = '${SECRET}'/" configuration_example.py > configuration.py

cd /opt/netbox/netbox
python manage.py migrate
expect -c "
spawn python manage.py createsuperuser --username ${USERNAME} --email ${MADDR}
expect \"Password: \"
send -- \"${PASSWORD}\n\"
expect \"Password (again): \"
send -- \"${PASSWORD}\n\"
expect \"Superuser created successfully.\"
"

REGIST=$(su - postgres -c "psql netbox <<_EOL_
select username from auth_user
_EOL_
" | grep -c ${USERNAME})

if [ ${REGIST} -ne 1 ]
then
	echo "createsuperuser ERROR"
	_motd fail
fi

python manage.py collectstatic --no-input

cat <<_EOL_> /etc/nginx/conf.d/netbox.conf
server {
    listen 80;

    server_name ${IPADDR};

    client_max_body_size 25m;

    location /static/ {
        alias /opt/netbox/netbox/static/;
    }

    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header X-Forwarded-Host \$server_name;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        add_header P3P 'CP="ALL DSP COR PSAa PSDa OUR NOR ONL UNI COM NAV"';
    }
}
_EOL_

cat <<_EOL_> /opt/netbox/gunicorn_config.py
command = '/usr/bin/gunicorn'
pythonpath = '/opt/netbox/netbox'
bind = '127.0.0.1:8001'
workers = 3
user = 'nginx'
_EOL_

cat <<_EOL_> /etc/supervisord.d/netbox.ini
[program:netbox]
command = gunicorn -c /opt/netbox/gunicorn_config.py netbox.wsgi
directory = /opt/netbox/netbox/
user = nginx
_EOL_

systemctl enable supervisord nginx

chown -R nginx. /opt/netbox/netbox

firewall-cmd --permanent --add-port=80/tcp
# firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='61.211.224.11/32' accept"
firewall-cmd --reload

# supervisord は rc-local.service 起動後でないと起動できない為、一度reboot
shutdown -r 1

_motd end
