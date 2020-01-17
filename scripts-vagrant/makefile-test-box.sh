#!/usr/bin/env bash
BOX_TESTED="$1"
VAGRANTFILE_TEMPLATE="$2"
BATS_FILE="$3"

CURRENT_DIR="$( cd "$( readlink -e "${BASH_SOURCE[0]%/*}" )" && pwd )"
ROOTDIR="$( cd "${CURRENT_DIR}/.." && pwd )"
SECONDS=0

# register-box:
vagrant box add --force --name "${USER}/${BOX}-${BOX_TESTED}-test" "${ROOTDIR}/${BOX_FILE_PREFIX}-${BOX_TESTED}/${UBUNTU_VERSION}-desktop.box"

function cleanBox {
    # clean box
    (
        cd "${ROOTDIR}/tests"
        vagrant destroy -f || true
        rm -rf Vagrantfile .vagrant || true
        vagrant box remove "${USER}/${BOX}-${BOX_TESTED}-test" || true
        rm -f "test_userData.vdi" || true
        vagrant global-status --prune
    )
}
trap cleanBox EXIT ABRT QUIT INT TERM

# execute tests
(
    cd ${ROOTDIR}/tests
    rm -f Vagrantfile
    cp "${VAGRANTFILE_TEMPLATE}" Vagrantfile
    sed -i \
        -e "s#@@@VAGRANT_BOX@@@#${USER}/${BOX}-${BOX_TESTED}-test#g" \
        -e "s#@@@BOX_TESTED@@@#${BOX_TESTED}#g" \
        Vagrantfile
    if "${ROOTDIR}/vendor/bats/libexec/bats" "./${BATS_FILE}"; then
        duration=$(eval "echo $(date -ud "@$SECONDS" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')")
        echo "Box ${BOX_PACKED} Tests ${BATS_FILE} OK on $(date) (duration: ${duration})" >> ../logs/box-${BOX_TESTED}-created
    fi
)
