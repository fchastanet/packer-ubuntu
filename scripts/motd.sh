#!/bin/bash

set -o errexit
set -x

echo "==> Recording box generation date"
echo "Server Box version ${BOX_VERSION} - $(date)" > /etc/vagrant_box_build_date

echo "==> Customizing message of the day"
MOTD_FILE="/etc/motd"
BANNER_WIDTH=64
BANNER="$(printf "%${BANNER_WIDTH}s" |tr " " "-")"
PLATFORM_RELEASE=$(uname -a | fold -w 64)

echo "${BANNER}" >> ${MOTD_FILE}
echo "${PLATFORM_RELEASE}" >> ${MOTD_FILE}

echo "${BANNER}" >> ${MOTD_FILE}
echo "Box version ${BOX_VERSION}" >> ${MOTD_FILE}
echo "server image built on $(date +%Y-%m-%d-%H-%M-%S)" >> ${MOTD_FILE}
