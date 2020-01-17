#!/usr/bin/env bash
set -x

# change root password
echo "root:root"| chpasswd

# Set up vagrant sudo
echo 'vagrant ALL=NOPASSWD:ALL' > /etc/sudoers.d/vagrant