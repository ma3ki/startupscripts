#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

sed -i '/^module(load="imjournal"/a \       ratelimit.interval="0"' /etc/rsyslog.conf
