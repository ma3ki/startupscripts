#!/bin/bash

FROM="$1"
TO="$2"

TAG=mailsend
PRI=mail.info
PID=$$
QD=/var/dovecot/queue

mkdir -p ${QD}
cat - > ${QD}/senddata.${PID}

# create queue
cat <<_EOL_> ${QD}/sendq.${PID}
cat ${QD}/senddata.${PID} | /usr/sbin/sendmail -i -f ${FROM} ${TO} >/dev/null 2>&1

if [ $? -eq 0 ]
then
	logger -t ${TAG} -p ${PRI} "from=<${FROM}>, to=<${TO}>, state=success"
	rm -f ${QD}/sendq.${PID} ${QD}/senddata.${PID}
else
	logger -t ${TAG} -p ${PRI} "from=<${FROM}>, to=<${TO}>, state=failure"
fi
_EOL_

exit 0

