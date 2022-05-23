#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

dnf install -y rsync rsync-daemon lsyncd

sed -i 's/^sync/-- sync/' /etc/lsyncd.conf

cat << _EOF_ >> /etc/lsyncd.conf
settings{
  statusFile = "/tmp/lsyncd.stat",
  statusInterval = 1,
}
sync{
  default.rsync,
  source="/var/dovecot/",
  target="${PRIVATEPAIR}::maildata",
}

_EOF_

echo "fs.inotify.max_user_watches = 1048576" > /etc/sysctl.d/98-lsyncd.conf
sysctl -p /etc/sysctl.d/98-lsyncd.conf

cat << _EOF_ >> /etc/rsyncd.conf
hosts allow = ${PRIVATEPAIR}
hosts deny = *
list = true
uid = root
gid = root
[maildata]
  path = /var/dovecot
  read only = false
_EOF_

firewall-cmd --add-port=873/tcp --permanent
firewall-cmd --reload
