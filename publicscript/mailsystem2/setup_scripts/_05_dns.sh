#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

cat dkim_ss1.ma3ki.net.keys | tr '\n' ' ' | sed -e 's/.*( "//' -e 's/".*"p=/p=/' -e 's/" ).*//'
v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCnB9xeOCIDwFxish0F5MSCYFtHsnOq5LhuNIcMdq6snKf8WbRKZCGqH2oeMW4HuqNLqG6B8iSZoUy5sdU+KcNkW1bqzxGO3THwLnztakAoWMr+s4GudHHp/GoJ77nIv4ftslrjiiW48Rmw9s8wO0WZztMvNWVOOJUUfvLHDHmKRQIDAQAB

