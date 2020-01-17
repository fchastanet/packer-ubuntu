#!/usr/bin/env bash

# inspired by https://github.com/niieani/bash-oo-framework

# shellcheck disable=2155
declare -g __rootLibPath="$( cd "${BASH_SOURCE[0]%/*}" && pwd )"
# shellcheck disable=2155,2034
declare -g __rootAssetsPath="${__rootLibPath}/assets"
# shellcheck disable=2155
declare -g __rootSrcPath__="$( cd "${__rootLibPath}/../../.." && pwd )"
# shellcheck disable=2155,2034
declare -g __rootVendorPath="$( cd "${__rootLibPath}/.." && pwd )"

# shellcheck source=.dev/vendor/bash-framework/System.sh
source "${__rootLibPath}/System.sh" || {
    cat <<< "FATAL ERROR: Unable to bootstrap (missing lib directory?)" 1>&2
    exit 1
}
# shellcheck source=.dev/vendor/bash-framework/array/Contains.sh
source "${__rootLibPath}/array/Contains.sh" || {
    cat <<< "FATAL ERROR: Unable to bootstrap (missing lib directory?)" 1>&2
    exit 1
}

System::bootstrap() {
    local -n instance=$1
    if [[ "${instance['INITIALIZED']:-0}" = "1" ]]; then
        return
    fi
    instance['DIR']="${__rootLibPath}"

    # System environment => os
    #uname GitBash windows (with wsl) => MINGW64_NT-10.0 ZOXFL-6619QN2 2.10.0(0.325/5/3) 2018-06-13 23:34 x86_64 Msys
    #uname GitBash windows (wo wsl)   => MINGW64_NT-10.0 frsa02-j5cbkc2 2.9.0(0.318/5/3) 2018-01-12 23:37 x86_64 Msys
    #uname wsl => Linux ZOXFL-6619QN2 4.4.0-17134-Microsoft #112-Microsoft Thu Jun 07 22:57:00 PST 2018 x86_64 x86_64 x86_64 GNU/Linux
    if [[ "$(uname -o)" = "Msys" ]]; then
        instance['IS_WINDOWS']=1
        instance['USER_ID']=1000
        instance['GROUP_ID']=1000
    else
        instance['IS_WINDOWS']=0
        instance['USER_ID']=$(id -u)
        instance['GROUP_ID']=$(id -g)
    fi
    instance['USER']=$(id -u -n)

    # default values
    instance['BASE_DIR']="${__rootSrcPath__}"
    instance['DISPLAY_LEVEL']=${__LEVEL_INFO}
    instance['LOG_LEVEL']=${__LEVEL_INFO}
    instance['LOG_FILE']=""

    # a log is generated when a command fails
    set -o errtrace

    # log level setting or info level by default
    instance['DISPLAY_LEVEL']=${DISPLAY_LEVEL:-${__LEVEL_INFO}}
    instance['LOG_LEVEL']=${LOG_LEVEL:-${__LEVEL_OFF}}
    instance['LOG_TIME_TRACKING']=${LOG_TIME_TRACKING:-0}

    if (( ${instance['LOG_LEVEL']} > ${__LEVEL_OFF} )); then
        if [[ ! -z "${LOG_FILE}" ]]; then
            if touch --no-create "${__rootSrcPath__}/${LOG_FILE}" ; then
                instance['LOG_FILE']="${__rootSrcPath__}/${LOG_FILE}"
            else
                Log::displayError "log file ${__rootSrcPath__}/${LOG_FILE} is not writable"
                instance['LOG_LEVEL']=${__LEVEL_OFF}
            fi
        else
            Log::displayError "LOG_FILE - log file not specified"
        fi
    fi

    instance['INITIALIZED']=1
}

## stubs in case either exception or log is not loaded
Log::displayError() { echo "Error: $1"; }

shopt -s expand_aliases
alias import="__bash_framework__allowFileReloading=false System::Import"
alias source="__bash_framework__allowFileReloading=true System::ImportOne"
alias .="__bash_framework__allowFileReloading=true System::ImportOne"

#########################
### INITIALIZE SYSTEM ###
#########################
# import .env file

if [[ "${__BASH_FRAMEWORK_IGNORE_ENV_LOADING__+x}" != "1" ]]; then
    set -o allexport
    # __BASH_FRAMEWORK_IGNORE_ENV_LOADING__ is unset
    if [ -f "/.env" ]; then
        # we are in the docker container
        # shellcheck source=.env
        source "/.env" || exit 1
    elif [ -f "${__rootSrcPath__}/.env" ]; then
        # shellcheck source=.env
        source "${__rootSrcPath__}/.env" || exit 1
    elif [ -f "${__rootSrcPath__}/.env.template" ]; then
        # shellcheck source=.env.template
        source "${__rootSrcPath__}/.env.template" || exit 1
    fi
    set +o allexport
fi

import bash-framework/Log
import bash-framework/Functions

# Bash will remember & return the highest exit code in a chain of pipes.
# This way you can catch the error inside pipes, e.g. mysqldump | gzip
set -o pipefail
set -o errexit
# use nullglob so that (file*.php) will return an empty array if no file matches the wildcard
shopt -s nullglob

export TERM=xterm-256color

# initialize bash_framework bootstrap
declare -Agx bootstrapSingleton
System::bootstrap bootstrapSingleton
