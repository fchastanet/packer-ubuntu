#!/usr/bin/env bash
set -o errexit
set -o pipefail
shopt -s nullglob

set -x

add-apt-repository ppa:libreoffice/ppa
apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    libreoffice
