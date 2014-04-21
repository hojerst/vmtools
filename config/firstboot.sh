#!/bin/sh

# update system
apt-get update
apt-get dist-upgrade -y

# create hostkey
dpkg-reconfigure openssh

# install chef
curl -L https://www.opscode.com/chef/install.sh | bash

# reboot system to get all updates
reboot
