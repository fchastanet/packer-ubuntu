#!/bin/bash
set -x
# this script will install default gnome desktop manager

if [[ "$DESKTOP" != "gnome" ]]; then
  exit 0
fi

set -o errexit
set -o pipefail
shopt -s nullglob

SSH_USER=${SSH_USERNAME:-vagrant}

echo "==> Checking version of Ubuntu"
cat /etc/lsb-release

echo "==> Installing ubuntu-desktop"
apt-get update -y --fix-missing
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    ubuntu-desktop
