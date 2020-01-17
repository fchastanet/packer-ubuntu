#!/usr/bin/env bash

CURRENT_DIR=$( cd "$( readlink -e "${BASH_SOURCE[0]%/*}" )" && pwd )

# shellcheck source=conf/.bin/Utils.sh
source "$(cd "${CURRENT_DIR}/../conf/.bin" && pwd)/Utils.sh"

PACKER_MINIMAL_VERSION="1.3.4"
VAGRANT_MINIMAL_VERSION="2.2.4"
VIRTUALBOX_MINIMAL_VERSION="6.0.10"

Version::checkMinimal "packer" "packer version" "${PACKER_MINIMAL_VERSION}" || {
  [[ "$1" = "packer-mandatory" ]] && exit 1
  Log::displayWarning "OK - packer is not needed in this case"
}
Version::checkMinimal "vagrant" "vagrant -v" "${VAGRANT_MINIMAL_VERSION}" || exit 1
Version::checkMinimal "vboxmanage" "vboxmanage --version" "${VIRTUALBOX_MINIMAL_VERSION}" || exit 1
