#!/bin/bash

FROM="$1"
TO="$2"

TAG=mailsend
PRI=mail.info

RESULT=$(cat - | sudo /usr/sbin/sendmail -i -f ${FROM} ${TO} 2>&1)

if [ $? -eq 0 ]
then
	logger -t ${TAG} -p ${PRI} "from=<${FROM}>, to=<${TO}>, state=success"
else
	logger -t ${TAG} -p ${PRI} "from=<${FROM}>, to=<${TO}>, state=failure, errmsg=${RESULT}"
fi

exit 0

