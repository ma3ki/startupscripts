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
       ETH1
  }
}

vrrp_script chk_myscript {
  script "/usr/local/bin/keepalived_track.sh"
  interval 5
  fail 2
  rise 2
}

vrrp_instance ETH1 {
  interface eth1
  virtual_router_id ${VRID}
  state BACKUP
  priority ${PRI}
  advert_int 5
  nopreempt
  authentication {
    auth_type PASS
    auth_pass sakura-p
  }
  virtual_ipaddress {
    ${PRIVATEVIP}
  }
  track_script {
    chk_myscript
  }
  notify_master "/usr/local/bin/keepalived_notify.sh master"
  notify_fault  "/usr/local/bin/keepalived_notify.sh backup"
  notify_backup "/usr/local/bin/keepalived_notify.sh backup"
  notify_stop   "/usr/local/bin/keepalived_notify.sh backup"
}
_EOL_


systemctl start keepalived
systemctl enable keepalived
#-- VRRPパケットの許可 (firewall-cmd --permanent --zone=trusted --add-interface=eth1 だけでいいかも)
firewall-cmd --add-rich-rule='rule protocol value="vrrp" accept' --permanent
firewall-cmd --reload

cp -p $(dirname $0)/../tools/keepalived_notify.sh /usr/local/bin
cp -p $(dirname $0)/../tools/keepalived_track.sh /usr/local/bin
