#!/usr/bin/env bash
set -o errexit
set -o pipefail
shopt -s nullglob

set -x

# install chrome
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb https://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list

# Update the box
apt-get -y update

# Install browsers
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    firefox \
    google-chrome-stable