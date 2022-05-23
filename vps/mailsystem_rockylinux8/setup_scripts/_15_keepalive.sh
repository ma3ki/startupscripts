#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- keepalived install

yum install -y keepalived
VRID=$(echo ${PRIVATEVIP} | awk -F\. '{print $4}')
PRI=$(echo ${PRIVATEPAIR} | awk -F\. '{print $4}')

cat << _EOL_ > /etc/keepalived/keepalived.conf
vrrp_sync_group VG1 {
  group {
       EM1
  }
}

vrrp_instance ETH1 {
  interface eth1
  virtual_router_id ${VRID}
  state BACKUP
  priority ${PRI}
  advert_int 5
  authentication {
    auth_type PASS
    auth_pass sakura-p
  }
  virtual_ipaddress {
    ${PRIVATEVIP}
  }
  notify_master "/usr/local/bin/keepalived_notify.sh master"
  notify_backup "/usr/local/bin/keepalived_notify.sh backup"
  notify_stop "/usr/local/bin/keepalived_notify.sh backup"
}
_EOL_


systemctl start keepalived
#-- VRRPパケットの受信を許可する。
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 1 -i eth1 -d 224.0.0.18 -p vrrp -j ACCEPT

#-- VRRPパケットの送信を許可する。
firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 1 -o eth1 -d 224.0.0.18 -p vrrp -j ACCEPT
firewall-cmd --reload

cp -p $(dirname $0)/../tools/keepalived_notify.sh /usr/local/bin
