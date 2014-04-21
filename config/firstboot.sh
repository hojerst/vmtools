#!/bin/sh

# update system
apt-get update
apt-get dist-upgrade -y

# create hostkey
dpkg-reconfigure openssh-server

# install chef
curl -L https://www.opscode.com/chef/install.sh | bash
