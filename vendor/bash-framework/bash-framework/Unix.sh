#!/usr/bin/env bash

import \
    bash-framework/Log

Unix::setTimezone() {
    local timezone="$1"

    System::expectUser root

    # set timezone
    if [[ -f "/usr/share/zoneinfo/${timezone}" ]]; then
        rm -f /etc/localtime
        rm -f /etc/timezone
        ln -snf "/usr/share/zoneinfo/${timezone}" /etc/localtime
        echo "${timezone}" > /etc/timezone
        DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true dpkg-reconfigure --frontend=noninteractive tzdata
    else
        Log::displayWarning "Timezone ${timezone} does not exists"
    fi
}


# add the line ip hostname at the end of /etc/hosts only if hostname does not exists yet in this file
# @param hostName
# @param ip (optional, default value: 127.0.0.1)
Unix::addHost() {
    local hostName="$1"
    local ip="${2:-127.0.0.1}"

    System::expectUser root

    if ! grep "${hostName}" /etc/hosts >/dev/null; then
        printf "${ip}\t${hostName}\n" >> /etc/hosts
    fi
}
