#!/bin/bash
#
# TO宛のメールをFROMのMBOXに移動するスクリプト

TO="$1"
MID="$2"
FROM="$3"
MBOX="$4"

TAG=mailmove
PRI=mail.info
PID=$$
QD=/var/dovecot/queue

mkdir -p ${QD}

# create queue
cat <<_EOL_> ${QD}/moveq.${PID}
# check mailbox
doveadm mailbox status -u ${FROM} all "${MBOX}"

# create mailbox
if [ $? -ne 0 ]
then
	doveadm mailbox create -u ${FROM} "${MBOX}"
	doveadm mailbox subscribe -u ${FROM} "${MBOX}"
fi

# check duplicate message
COUNT=$(doveadm search -u ${FROM} mailbox "${MBOX}" header message-id "${MID}" since 2mins | wc -l)
if [ ${COUNT} -eq 0 ]
then
	doveadm move -u ${FROM} "${MBOX}" user ${TO} mailbox INBOX header message-id "${MID}" since 2mins >/dev/null 2>&1

	if [ $? -eq 0 ]
	then
		logger -t ${TAG} -p ${PRI} "from=<${FROM}>, mbox=${MBOX}, to=<${TO}>, mid=${MID}, state=success"
		rm -f ${QD}/moveq.${PID}
	else
		logger -t ${TAG} -p ${PRI} "from=<${FROM}>, mbox=${MBOX}, to=<${TO}>, mid=${MID}, state=failure"
	fi
else
	logger -t ${TAG} -p ${PRI} "from=<${FROM}>, mbox=${MBOX}, to=<${TO}>, mid=${MID}, state=skip"
fi

_EOL_

exit 0

