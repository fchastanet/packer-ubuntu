#!/bin/sh
set -x


# Update the box
apt-get -y update

DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

# configure language support
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    tzdata \
    $(check-language-support)

# Install dependencies
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    curl \
    dos2unix \
    git \
    libappindicator1 \
    libindicator7 \
    libxss1 \
    nfs-common \
    putty-tools \
    vim \
    vim-gui-common \
    vim-runtime \
    wget