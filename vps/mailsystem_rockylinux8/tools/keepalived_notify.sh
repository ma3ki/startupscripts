#!/bin/bash
#
# usage) ./keepalived_notify.sh (master|backup) 

usage() {
	echo "usage)"
	echo "$0 (master|backup)"
	exit 1
}

if [ "$#" -ne 1 ]
then
	usage
fi

if [ "$1" = "master" ]
then
	systemctl stop rsyncd
	systemctl start lsyncd
	systemctl start dovecot
elif [ "$1" = "backup" ]
then
	systemctl stop dovecot
	systemctl stop lsyncd
	systemctl start rsyncd
fi

exit 0
