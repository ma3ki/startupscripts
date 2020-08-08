#!/bin/bash -e
#
# ./create_domain.sh <domain>

source $(dirname $0)/../config.source
echo "---- $0 ----"

mkdir -p ${WORKDIR}/ldap

if [ $# -ne 0 ]
then
  DOMAIN_LIST="$*"
fi

for domain in ${DOMAIN_LIST}
do
	account=$(echo ${ADMINS} | awk '{print $1}')
	BASE=$(echo ${domain} | sed -e 's/\(^\|\.\)/,dc=/g' -e 's/^,//')
	if [ $(ldapsearch -h ${LDAP_MASTER} -x -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -b "${BASE}" | grep -c ^dn:) -eq 0 ]
	then
		cat <<-_EOL_>>${WORKDIR}/ldap/${domain}.ldif
		dn: ${BASE}
		objectClass: dcObject
		objectClass: organization
		dc: ${x}
		o: ${domain}
		
		_EOL_
	fi

	#-- create root
	while :;
	do
		COUNT=1
		if [ $(dsconf localhost backend suffix list | fgrep -ci "(userroot${COUNT})") -eq 0 ]
		then
			dsconf localhost backend create --suffix ${BASE} --be-name userRoot${COUNT}
			break
		else
			COUNT=$(expr ${COUNT} + 1)
		fi
	done

	PEOPLE="ou=People,${BASE}"
	TERMED=$(echo ${PEOPLE} | sed 's/ou=People/ou=Termed/')

	cat <<-_EOL_>>${WORKDIR}/ldap/${domain}.ldif
	dn: ${PEOPLE}
	ou: People
	objectclass: organizationalUnit

	dn: ${TERMED}
	ou: Termed
	objectclass: organizationalUnit
	
	dn: uid=${account},${PEOPLE}
	objectClass: mailRecipient
	objectClass: top
	userPassword: ${ROOT_PASSWORD}
	mailMessageStore: ${STORE_SERVER}
	mailHost: ${OUTBOUND_MTA_SERVER}
	mailAccessDomain: ${domain}
	mailRoutingAddress: ${account}@${domain}
	mailAlternateAddress: ${account}@${domain}
	_EOL_

	for alt in ${ADMINS}
	do
		if [ "${alt}" = "${account}" ]
		then
			continue
		fi
		echo "mailAlternateAddress: ${alt}@${domain}" >> ${WORKDIR}/ldap/${domain}.ldif
	done

	echo >> ${WORKDIR}/ldap/${domain}.ldif
	ldapadd -x -h ${LDAP_MASTER} -D "${ROOT_DN}" -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/${domain}.ldif
	mv -f ${WORKDIR}/ldap/${domain}.ldif ${WORKDIR}/ldap/${domain}_admin.ldif
	echo "${account}@${domain}: ${ROOT_PASSWORD}" >> ${WORKDIR}/password.list

	#-- acl
	echo "dn: ${BASE}" > ${WORKDIR}/ldap/${domain}_acl.ldif
	cat <<-'_EOL_'>> ${WORKDIR}/ldap/${domain}_acl.ldif
	changeType: modify
	replace: aci
	aci: (targetattr="UserPassword")(target!="ldap:///uid=*,ou=Termed,dc=*")(version 3.0; acl "1"; allow(write) userdn="ldap:///self";)
	aci: (targetattr="UserPassword")(target!="ldap:///uid=*,ou=Termed,dc=*")(version 3.0; acl "2"; allow(compare) userdn="ldap:///anyone";)
	aci: (targetattr="*")(target!="ldap:///uid=*,ou=Termed,dc=*")(version 3.0; acl "3"; allow(search) userdn="ldap:///anyone";)
	aci: (targetattr="uid||mail*")(target!="ldap:///uid=*,ou=Termed,dc=*")(version 3.0; acl "4"; allow(read) userdn="ldap:///anyone";)
	aci: (targetattr="*")(target!="ldap:///uid=*,ou=Termed,dc=*")(version 3.0; acl "5"; allow(read) userdn="ldap:///self";)
	_EOL_
	ldapmodify -D ${ROOT_DN} -w ${ROOT_PASSWORD} -f ${WORKDIR}/ldap/${domain}_acl.ldif

done

