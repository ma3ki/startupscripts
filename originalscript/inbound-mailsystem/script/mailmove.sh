#!/bin/bash
#
# TO宛のメールをFROMのMBOXに移動するスクリプト

TO="$1"
MID="$2"
FROM="$3"
MBOX="$4"

TAG=mailmove
PRI=mail.info

RESULT=$(doveadm move -u ${FROM} "${MBOX}" user ${TO} mailbox INBOX header message-id "${MID}" since 1mins 2>&1)

if [ $? -eq 0 ]
then
	logger -t ${TAG} -p ${PRI} "from=<${FROM}>, mbox=${MBOX}, to=<${TO}>, mid=${MID}, state=success"
else
	logger -t ${TAG} -p ${PRI} "from=<${FROM}>, mbox=${MBOX}, to=<${TO}>, mid=${MID}, state=failure, errmsg=${RESULT}"
fi

exit 0

