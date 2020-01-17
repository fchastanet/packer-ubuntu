#!/bin/bash
set -x
# this script will install x11 dependencies
if [[ "$DESKTOP" != "serverX11" ]]; then
  exit 0
fi

set -o errexit
set -o pipefail
shopt -s nullglob

echo "==> install x11 dependencies"
# Update the box
apt-get -y update

# Install browsers
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    openbox \
    xorg
