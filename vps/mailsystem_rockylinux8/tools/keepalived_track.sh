#!/bin/bash -e

check_proc() {
	PROC=$1
	USER=$2
	if [ $(ps -eo user,cmd | grep "^${USER} " | sed "s/${USER}//" | grep ${PROC} | grep -vc grep) -eq 0 ]
	then
		echo "ERROR: ${PROC}"
		exit 1
	elif [ "${PROC}" = "master" ]
	then 
		echo "OK: postfix"
	else
		echo "OK: ${PROC}"
	fi
}

check_proc ns-slapd dirsrv 
check_proc rspamd _rspamd
check_proc redis-server redis
check_proc master root
check_proc php-fpm nginx
check_proc nginx nginx

if [ $(ip addr show eth1 | egrep -c " ([0-9]+\.){3}[0-9]+/32 ") -eq 1 ]
then
  check_proc dovecot dovecot
  check_proc lsyncd root
else
  check_proc rsync root
fi

exit 0
