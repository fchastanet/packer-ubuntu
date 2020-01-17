#!/usr/bin/env bash
set -o errexit
set -o pipefail
shopt -s nullglob

set -x

# Update the box
apt-get -y update

# Install browsers
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    gedit \
    terminator