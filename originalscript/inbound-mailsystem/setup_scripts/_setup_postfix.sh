#!/bin/bash -x
set -e

source $(dirname $0)/../config.source
echo "---- $0 ----"

yum install -y cyrus-sasl-plain

alternatives --set mta /usr/sbin/sendmail.postfix
yum remove -y sendmail

# setup postfix
postmulti -e init
postmulti -I postfix-inbound -e create

postconf -c /etc/postfix -e inet_interfaces=127.0.0.1
postconf -c /etc/postfix -e inet_protocols=ipv4
postconf -c /etc/postfix -e smtpd_milters=inet:${DKIM_SERVER}:${DKIM_PORT}
postconf -c /etc/postfix -e non_smtpd_milters=inet:${DKIM_SERVER}:${DKIM_PORT}
postconf -c /etc/postfix -e authorized_submit_users=static:anyone

postconf -c /etc/postfix-inbound -e inet_interfaces=127.0.0.1
postconf -c /etc/postfix-inbound -e inet_protocols=ipv4
postconf -c /etc/postfix-inbound -e myhostname=${FIRST_DOMAIN}
postconf -c /etc/postfix-inbound -e smtpd_milters=inet:${CLAMAV_SERVER}:${CLAMAV_PORT}
postconf -c /etc/postfix-inbound -e smtpd_authorized_xclient_hosts=${XAUTH_HOST}
postconf -c /etc/postfix-inbound -e smtpd_sasl_auth_enable=yes
postconf -c /etc/postfix-inbound -e smtpd_sender_restrictions=reject_sender_login_mismatch
postconf -c /etc/postfix-inbound -e smtpd_sender_login_maps=ldap:/etc/postfix/ldapsendercheck.cf
postconf -c /etc/postfix-inbound -e transport_maps=hash:/etc/postfix-inbound/transport
postconf -c /etc/postfix-inbound -X master_service_disable

sed -i -e 's/^smtp/#smtp/' -e 's/^#submission/submission/' /etc/postfix-inbound/master.cf

cat <<_EOL_>> /etc/postfix-inbound/transport
*	lmtp:[127.0.0.1]:24
_EOL_
postmap /etc/postfix-inbound/transport

for cf in /etc/postfix/main.cf /etc/postfix-inbound/main.cf
do
	cat <<-_EOL_>> ${cf}
	milter_default_action = tempfail
	milter_protocol = 6
	smtpd_junk_command_limit = 20
	smtpd_helo_required = yes
	smtpd_hard_error_limit = 5
	message_size_limit = 20480000
	# anvil_rate_time_unit = 60s
	# smtpd_recipient_limit = 50
	# smtpd_client_connection_count_limit = 15
	# smtpd_client_message_rate_limit = 100
	# smtpd_client_recipient_rate_limit = 200
	# smtpd_client_connection_rate_limit = 100
	disable_vrfy_command = yes
	smtpd_discard_ehlo_keywords = dsn, enhancedstatuscodes, etrn
	smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt
	smtp_tls_security_level = may
	smtp_tls_loglevel = 1
	lmtp_host_lookup = native
	smtp_host_lookup = native
	_EOL_
done

cat <<_EOL_>/etc/postfix-inbound/ldaprcptcheck.cf
server_host = ${LDAP_SERVER}
bind = no
version = 3
scope = sub
timeout = 15
query_filter = (&(objectClass=inetLocalMailRecipient)(mailLocalAddress=%s))
result_attribute = mailRoutingAddress
result_format = OK
_EOL_

cat <<_EOL_>/etc/postfix-inbound/ldaptransport.cf
server_host = ${LDAP_SERVER}
bind = no
version = 3
scope = sub
timeout = 15
query_filter = (&(objectClass=inetLocalMailRecipient)(mailLocalAddress=%s))
result_attribute = mailHost
result_format = lmtp:[%s]:${LMTP_PORT}
_EOL_

cat <<_EOL_>/etc/postfix/ldapsendercheck.cf
server_host = ${LDAP_SERVER}
bind = no
version = 3
scope = sub
timeout = 15
query_filter = (&(objectClass=inetLocalMailRecipient)(mailRoutingAddress=%s))
result_attribute = mailRoutingAddress
result_format = %s
_EOL_

systemctl restart postfix

postmulti -i postfix-inbound -e enable
postmulti -i postfix-inbound -p start

sed -i "s/^postmaster:.*/postmaster:	root@${FIRST_DOMAIN}/" /etc/aliases
newaliases

