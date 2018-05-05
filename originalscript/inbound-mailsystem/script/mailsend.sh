#!/bin/bash

FROM="$1"
TO="$2"

TAG=mailsend
PRI=mail.info

# create queue
cat - | /usr/sbin/sendmail -i -f ${FROM} ${TO} >/dev/null 2>&1

if [ $? -eq 0 ]
then
	logger -t ${TAG} -p ${PRI} "from=<${FROM}>, to=<${TO}>, state=success"
else
	logger -t ${TAG} -p ${PRI} "from=<${FROM}>, to=<${TO}>, state=failure"
fi

exit 0

