#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- dovecot のインストール
dnf install -y dovecot dovecot-pigeonhole openldap-devel expat-devel bzip2-devel zlib-devel

#-- dovecot の設定
cat <<_EOL_> /etc/dovecot/local.conf
postmaster_address = postmater@${FIRST_DOMAIN}
auth_mechanisms = plain login
deliver_log_format = from=%{from_envelope}, to=%{to_envelope}, size=%p, msgid=%m, delivery_time=%{delivery_time}, session_time=%{session_time}, %\$
disable_plaintext_auth = no
first_valid_uid = 97
mail_location = maildir:/var/dovecot/%Ld/%Ln
mail_plugins = \$mail_plugins zlib quota
plugin {
  sieve = /var/dovecot/%Ld/%Ln/dovecot.sieve
  sieve_extensions = +notify +imapflags +editheader +vacation-seconds
  sieve_max_actions = 32
  sieve_max_redirects = 10
  sieve_redirect_envelope_from = recipient
  sieve_vacation_min_period = 1h
  sieve_vacation_default_period = 7d
  sieve_vacation_max_period = 60d
  zlib_save = bz2
  zlib_save_level = 5
  quota = count:User quota
  quota_rule = *:storage=3G
  quota_vsizes = yes
  quota_grace = 5%%
  quota_status_success = DUNNO
  quota_status_nouser = DUNNO
  quota_status_overquota = "552 5.2.2 Mailbox is full"
}
protocols = imap pop3 lmtp sieve
service imap-login {
  inet_listener imap {
    address = ${DOVECOT_SERVER}
  }
}
service lmtp {
  inet_listener lmtp {
    address = ${DOVECOT_SERVER}
    port = ${LMTP_PORT}
  }
}
service pop3-login {
  inet_listener pop3 {
    address = ${DOVECOT_SERVER}
  }
}
service managesieve-login {
  inet_listener sieve {
    address = ${DOVECOT_SERVER}
  }
}
service quota-status {
  executable = quota-status -p postfix
  inet_listener {
    port = 12340
  }
  client_limit = 1
}
protocol lmtp {
  mail_plugins = \$mail_plugins sieve
}
protocol imap {
  mail_plugins = \$mail_plugins imap_quota
  mail_max_userip_connections = 20
}
protocol \!indexer-worker {
  mail_vsize_bg_after_count = 100
}
ssl = no
ssl_cert =
ssl_key =
lmtp_save_to_detail_mailbox = yes
lda_mailbox_autocreate = yes
lda_mailbox_autosubscribe = yes
mailbox_list_index = yes
passdb {
  driver = static
  args = nopassword=y
}
!include_try domain.d/*.conf
_EOL_

mkdir /etc/dovecot/domain.d

for base in $(for domain in ${DOMAIN_LIST}
  do
    echo "${domain}" > /tmp/dovecot_install.tmp
    tmpdc=""
    for dc in $(echo ${domain} | sed 's/\./ /g')
    do
      tmpdc="${tmpdc}dc=${dc},"
    done
    echo ${tmpdc}
  done | sed 's/,$//')
do
tmpdomain=$(cat /tmp/dovecot_install.tmp)
cat <<_EOL_>>/etc/dovecot/domain.d/dovecot-userdb_${tmpdomain}.conf
userdb {
  args = /etc/dovecot/domain.d/dovecot-ldap_${tmpdomain}.conf.ext
  driver = ldap
}
_EOL_

cat <<_EOL_>/etc/dovecot/domain.d/dovecot-ldap_${tmpdomain}.conf.ext
hosts = ${LDAP_SERVER}
auth_bind = yes
base = ${base}
pass_attrs=mailRoutingAddress=User,userPassword=password
pass_filter = (mailRoutingAddress=%u)
user_attrs = \
  =uid=dovecot, \
  =gid=dovecot, \
  =mail=maildir:/var/dovecot/%Ld/%Ln, \
  =home=/var/dovecot/%Ld/%Ln, \
  mailQuota=quota_rule=*:bytes=%\$
user_filter = (mailRoutingAddress=%u)
iterate_attrs = mailRoutingAddress=user
iterate_filter = (mailRoutingAddress=*)
_EOL_

  cnt=$(($cnt + 1))
done

sed -i 's/^\!include auth-system.conf.ext/#\|include auth-system.conf.ext/' /etc/dovecot/conf.d/10-auth.conf

mkdir /var/dovecot
chown dovecot. /var/dovecot

#-- dovecot の起動
# systemctl enable dovecot
# systemctl start dovecot

