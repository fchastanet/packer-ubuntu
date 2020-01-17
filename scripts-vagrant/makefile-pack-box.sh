#!/usr/bin/env bash

set -o errexit
set -o pipefail
shopt -s nullglob

set -x

PACKER_FILE="$1"
BOX_PACKED="$2"
LOG_FILE="$3"

echo "------------------------------------------------------------------------------------------"
echo "pack box ${PACKER_FILE}"
echo "------------------------------------------------------------------------------------------"
SECONDS=0
echo "Build started at $(date)" > logs/box-${BOX_PACKED}-created

packer validate ${PACKER_FILE}
PACKER_LOG=1 packer build \
    -var "version=${BOX_VERSION}" \
    -var "box_version=${BOX_VERSION}" \
    -var "headless=${HEADLESS}" \
    -var "desktop=${BOX_PACKED}" \
    -var "docker_compose_version=${DOCKER_COMPOSE_VERSION}" \
    -var "ubuntu_version=${UBUNTU_VERSION}" \
    -var "cloud_token=${CLOUD_TOKEN}" \
    -var "cloud_tag=${USER}/${BOX}-${BOX_PACKED}" \
    -var "iso_url=${UBUNTU_ISO_URL}" \
    -var "iso_name=${UBUNTU_ISO_NAME}" \
    -var "iso_checksum=${UBUNTU_ISO_CHECKSUM}" \
    ${PACKER_FILE} 2>&1 | tee "${LOG_FILE}"

duration=$(eval "echo $(date -ud "@$SECONDS" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')")
echo "Built at $(date)" >> logs/box-${BOX_PACKED}-created
echo "Box ${BOX_PACKED} build has taken ${duration}" >> logs/box-${BOX_PACKED}-created
