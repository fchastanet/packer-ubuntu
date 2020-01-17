#!/usr/bin/env bash

# call a given command without
# stdout of the command is returned in global variable COMMAND_OUTPUT
# @return exit code of the command
Functions::callCommandSafely() {
    local command=$1
    local logMessage="$2"
    local returnCode=1

    Log::displayInfo "Start - ${logMessage}"
    Log::displayDebug "execute command ${command}"

    # trick, we capture stdout in variable COMMAND_OUTPUT
    # and we copy also (via tee) stdout to stderr to be able to follow progress of the command
    if COMMAND_OUTPUT=$(bash -c "${command}" | tee /dev/stderr); then
        returnCode=0
    fi

    return ${returnCode}
}

Functions::checkCommandExists() {
    local commandName="$1"
    local helpIfNotExists="$2"

    Log::displayInfo "check ${commandName} version"
    which ${commandName} >/dev/null 2>/dev/null || {
        Log::displayError "${commandName} is not installed, please install it"
        if [[ ! -z "${helpIfNotExists}" ]]; then
            Log::displayInfo "${helpIfNotExists}"
        fi
        exit 1
    }
}

# @return 1 if on windows system
Functions::isWindows() {
    return ${bootstrapSingleton['IS_WINDOWS']}
}

# check if param is a valid bash_framework directory (only check if directory /app exixts)
# @param $1 the dns hostname
# @return 1 on error
Functions::validateProjectHostDir() {
    [[ -d "$1/app" ]]
}

# check if param is valid dns hostname (known bug é characters are considered OK)
# @param $1 the dns hostname
# @return 1 on error
Functions::validateDnsHostname() {
    local regexp="^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$"
    if [[ $1 =~ ${regexp} ]]; then
        return 0
    else
        return 1
    fi
}

Functions::validateFirstNameLastName() {
    local regexp="^[^ ]+ ([^ ]+[ ]?)+$"
    if [[ $1 =~ ${regexp} ]]; then
        return 0
    else
        return 1
    fi
}

# check if param is valid email address without @ part
# @param $1 the email address
# @return 1 on error
Functions::validateCkEmailAddress() {
    local regexp="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$"
    if [[ "$1" =~ ${regexp} ]]; then
        return 0
    else
        return 1
    fi
}

# try to ping the dns
# @param $1 is the dns hostname
# @return 1 on error
Functions::checkDnsHostname() {
    local host="$1"
    if [ -z "${host}" ]; then
        return 1
    fi

    # check if host is reachable
    local returnCode=0
    if [ "$(Functions::isWindows; echo $?)" = "1" ]; then
        Functions::callCommandSafely "ping -4 -n 1 ${host}" "try to reach host ${host}"
        returnCode=$?
    else
        Functions::callCommandSafely "ping -c 1 ${host}" "try to reach host ${host}"
        returnCode=$?
    fi

    if [ "${returnCode}" = "0" ]; then
        # get ip from ping outputcallCommandSafely
        # under windows: Pinging my.url.lan [127.0.0.1] with 32 bytes of data
        # under linux: PING my.url.lan (127.0.1.1) 56(84) bytes of data.
        local ip
        ip=$(echo ${COMMAND_OUTPUT} | grep -i ping | grep -Eo '[0-9.]{4,}' | head -1)

        # now we have to check if ip is bound to local ip address
        if [[ ${ip} != 127.0.* ]]; then
            # resolve to a non local address
            # check if ip resolve to our ips
            message="check if ip(${ip}) associated to host(${host}) is listed in your network configuration"
            if [ "$(Functions::isWindows; echo $?)" = "1" ]; then
                Functions::callCommandSafely "ipconfig | grep ${ip} | cat" "${message}"
                returnCode=$?
            else
                Functions::callCommandSafely "ifconfig | grep ${ip} | cat" "${message}"
                returnCode=$?
            fi
            if [ "${returnCode}" != "0" ]; then
                returnCode=2
            elif [ -z "${COMMAND_OUTPUT}" ]; then
                returnCode=3
            fi
        fi
    fi

    return ${returnCode}
}


# add host to git known host if not already present
# @param hostName
Functions::addGitKnownHost() {
    local hostName="$1"
    local knownHostsFile="${HOME}/.ssh/known_hosts"
    touch "${knownHostsFile}"
    if ! grep "${hostName}" "${knownHostsFile}" >/dev/null 2>/dev/null; then
        ssh-keyscan "${hostName}" >> "${knownHostsFile}"
    fi
}

Functions::quote() {
    local quoted=${1//\'/\'\\\'\'};
    printf "'%s'" "$quoted"
}
