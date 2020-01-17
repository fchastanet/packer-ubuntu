#!/bin/bash
set -x
# this script will set common configuration

set -o errexit
set -o pipefail
shopt -s nullglob

SSH_USER=${SSH_USERNAME:-vagrant}

echo "==> common configuration"

echo "==> ensure we have last ubuntu version"
DEBIAN_FRONTEND=noninteractive apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

echo "==> configure fr keyboard"
L='fr' && sed -i 's/XKBLAYOUT=\"\w*"/XKBLAYOUT=\"'$L'\"/g' /etc/default/keyboard

# sync datetime auto
timedatectl set-ntp false
timedatectl set-ntp true

# disable sleep mode
echo "==> disable sleep mode"
systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target

# enable hibernate
echo "=> enable hibernate"
# TODO http://ubuntuhandbook.org/index.php/2018/05/add-hibernate-option-ubuntu-18-04/
sed -i -re 's@^#?HandleLidSwitch=.*$@HandleLidSwitch=hibernate@g' /etc/systemd/logind.conf
sed -i -re 's@^#?HandleHibernateKey=.*$@HandleHibernateKey=hibernate@g' /etc/systemd/logind.conf

# raise inotify limit
if [[ ! -f /etc/sysctl.d/99-idea.conf ]]; then
    echo "=> raise inotify limit"
    echo "fs.inotify.max_user_watches = 524288" > /etc/sysctl.d/99-idea.conf
    sysctl -p --system
fi
