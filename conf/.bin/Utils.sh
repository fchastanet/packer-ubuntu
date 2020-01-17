#!/usr/bin/env bash

######################################################################################
#### Functions
######################################################################################

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

Functions::validateFirstNameLastName() {
    local regexp="^[^ ]+ ([^ ]+[ ]?)+$"
    if [[ $1 =~ ${regexp} ]]; then
        return 0
    else
        return 1
    fi
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
        return 1
    }
    return 0
}

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
    Functions::callCommandSafely "ping -c 1 ${host}" "try to reach host ${host}"
    returnCode=$?

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

######################################################################################
#### Version
######################################################################################

Version::checkMinimal() {
    local commandName="$1"
    local commandVersion="$2"
    local minimalVersion="$3"

    Functions::checkCommandExists "${commandName}"

    local version
    version=$(${commandVersion} | sed -nre 's/^[^0-9]*(([0-9]+\.)*[0-9]+).*/\1/p' | head -n1)

    Log::displayDebug "check ${commandName} version ${version} against minimal ${minimalVersion}"

    Version::compare "${version}" "${minimalVersion}" || {
        local result=$?
        if [[ "${result}" = "1" ]]; then
            Log::displayWarning "${commandName} version is ${version} greater than ${minimalVersion}, OK let's continue"
        elif [[ "${result}" = "2" ]]; then
            Log::displayError "${commandName} minimal version is ${minimalVersion}, your version is ${version}"
            return 1
        fi
        return 0
    }

}

# @param $1 version 1
# @param $2 version 2
# @return
#   0 if equal
#   1 if version1 > version2
#   2 else
Version::compare() {
    if [[ "$1" = "$2" ]]
    then
        return 0
    fi
    local IFS=.
    # shellcheck disable=2206
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z "${ver2[i]+unset}" ]] || [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

######################################################################################
#### Logs
######################################################################################

# log level constants
readonly __LEVEL_OFF=0
readonly __LEVEL_ERROR=1
readonly __LEVEL_WARNING=2
readonly __LEVEL_INFO=3
readonly __LEVEL_SUCCESS=3
readonly __LEVEL_DEBUG=4

# check colors applicable https://misc.flogisoft.com/bash/tip_colors_and_formatting
readonly __ERROR_COLOR='\e[31m'           # Red
readonly __INFO_COLOR='\e[44m'            # white on lightBlue
readonly __SUCCESS_COLOR='\e[32m'         # Green
readonly __WARNING_COLOR='\e[33m'         # Yellow
readonly __DEBUG_COLOR='\e[37m'           # Grey
readonly __TIME_TRACKING_COLOR='\e[37m'   # Grey
readonly __RESET_COLOR='\e[0m'            # Reset Color

Log::displayError() {
    local msg="ERROR - ${1}"
    if (( ${bootstrapSingleton['DISPLAY_LEVEL']} >= ${__LEVEL_ERROR} )); then
        echo -e "${__ERROR_COLOR}${msg}${__RESET_COLOR}"
    fi
    Log::logMessage ${__LEVEL_ERROR} "${msg}"
}

Log::displayWarning() {
    local msg="WARN  - ${1}"
    if (( bootstrapSingleton['DISPLAY_LEVEL'] >= __LEVEL_WARNING )); then
        echo -e "${__WARNING_COLOR}${msg}${__RESET_COLOR}"
    fi
    Log::logMessage ${__LEVEL_WARNING} "${msg}"
}

Log::displayInfo() {
    local msg="INFO  - ${1}"
    if (( ${bootstrapSingleton['DISPLAY_LEVEL']} >= ${__LEVEL_INFO} )); then
        echo -e "${__INFO_COLOR}${msg}${__RESET_COLOR}"
    fi
    Log::logMessage ${__LEVEL_INFO} "${msg}"
}

Log::displaySuccess() {
    local msg="${1}"
    echo -e "${__SUCCESS_COLOR}${msg}${__RESET_COLOR}"
    Log::logMessage ${__LEVEL_SUCCESS} "${msg}"
}


Log::displayDebug() {
    local msg="DEBUG - ${1}"

    if (( ${bootstrapSingleton['DISPLAY_LEVEL']} >= ${__LEVEL_DEBUG} )); then
        echo -e "${__DEBUG_COLOR}${msg}${__RESET_COLOR}"
    fi
    Log::logMessage ${__LEVEL_DEBUG} "${msg}"
}

Log::logMessage() {
    local minLogLevel=$1
    local msg="$2"
    local date

    if (( ${bootstrapSingleton['LOG_LEVEL']} >= ${minLogLevel} )); then
        date="$(date '+%Y-%m-%d %H:%M:%S')"
        echo "${date} - ${msg}" >> "${bootstrapSingleton['LOG_FILE']}"
    fi
}

######################################################################################
#### INIT
######################################################################################


shopt -s expand_aliases
set -o pipefail
set -o errexit
# use nullglob so that (file*.php) will return an empty array if no file matches the wildcard
shopt -s nullglob
export TERM=xterm-256color
# a log is generated when a command fails
set -o errtrace

declare -Agx bootstrapSingleton
bootstrapSingleton['DISPLAY_LEVEL']=${DISPLAY_LEVEL:-${__LEVEL_INFO}}
bootstrapSingleton['LOG_LEVEL']=${LOG_LEVEL:-${__LEVEL_OFF}}