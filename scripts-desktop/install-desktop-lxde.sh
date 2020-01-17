#!/bin/bash
set -x

# this script will install https://lxde.net/ desktop manager

if [[ "$DESKTOP" != "lxde" ]]; then
  exit 0
fi

set -o errexit
set -o pipefail
shopt -s nullglob

SSH_USER=${SSH_USERNAME:-vagrant}

echo "==> Checking version of Ubuntu"
cat /etc/lsb-release

echo "==> Installing lxde"
apt-get update -y --fix-missing
DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    lightdm \
    lightdm-gtk-greeter \
    lubuntu-default-settings \
    lxappearance \
    lxterminal \
    x11-xkb-utils

echo "==> Installing lxpanel (taskbar)"
DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    lxpanel

echo "==> Installing lxsession (auto start application)"
DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    lxsession

echo "==> Installing openbox - see https://doc.ubuntu-fr.org/openbox"
DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    obconf \
    obmenu \
    openbox

#DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
#    xserver-xorg \
#    xserver-xorg-video-all

echo "==> auto login at startup"
cat <<- EOF > /etc/X11/xorg.conf
[SeatDefaults]
autologin-user=vagrant
autologin-user-timeout=0
# Check https://bugs.launchpad.net/lightdm/+bug/854261 before setting a timeout
user-session=lxde
greeter-session=lightdm-gtk-greeter
EOF