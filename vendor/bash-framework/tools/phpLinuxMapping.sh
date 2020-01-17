#!/usr/bin/env bash

# Here the env variables that can be set
# DOCKER_CONTAINER
#   The container on which the command will be executed
#   Default value: bash_framework-web
# DOCKER_TARGET_DIR
#   The target directory on the container
#   Default value: /data/bash_framework
# DOCKER_SERVER_NAME
#   The value that will be sent to xdebug in order to do the mapping
#   see PhpStorm Settings PHP > Servers
#   Default Value: trunk.${DNS_HOSTNAME}
# DOCKER_HOST_ROOT_DIR
#   full path on the host to the root dir of the repository containing this file
#   Default value: full path on the host to the root dir of the repository containing this file
# DOCKER_HOST_TARGET_ROOT_DIR
#   full path on the host to the root dir that is actually mapped to DOCKER_TARGET_DIR
#   Default value: ${PROJECT_HOST_DIR}

# output is disabled if arguments contains ide-phpinfo.php
# otherwise phpstorm cannot be configured
__PHP_LINUX_MAPPING_OUTPUT_ENABLED=0
__PHP_LINUX_MAPPING_DEBUG=0
__PHP_LINUX_MAPPING_LOG_FILE="${HOME}/script.log"

# load bash_framework-bootstrap
# shellcheck source=.dev/vendor/bash-framework/_bootstrap.sh
source "$( cd "$( readlink -e "${BASH_SOURCE[0]%/*}/.." )" && pwd )/vendor/bash-framework/_bootstrap.sh"

# transform PhpStorm arguments
PHP_PARAMS=""
ENV_VARS=""
__PHP_LINUX_MAPPING_DOCKER_CONTAINER="bash_framework-web"
__PHP_LINUX_MAPPING_DOCKER_TARGET_DIR="/data/bash_framework"
__PHP_LINUX_MAPPING_DOCKER_SERVER_NAME=""
__PHP_LINUX_MAPPING_DOCKER_HOST_ROOT_DIR="${__rootSrcPath__}"
__PHP_LINUX_MAPPING_DOCKER_HOST_TARGET_ROOT_DIR="$(cd "${__rootSrcPath__}/${PROJECT_HOST_DIR}" && pwd)"

CONTAINER_USER="${CONTAINER_USER:-www-data}"

# be sure that parameters are not interpreted by bash
set -o noglob

# first parse parameters
# DOCKER_CONTAINER and DOCKER_TARGET_DIR can be overridden adding this to the parameters
# -dDOCKER_CONTAINER=
# -dDOCKER_TARGET_DIR=
# -dDOCKER_SERVER_NAME=
# -dDOCKER_HOST_ROOT_DIR=
# -dDOCKER_HOST_TARGET_ROOT_DIR=
function preparseParameters() {
    # tokenize param 1 upon space
    for arg in "$@"
    do
        param="${arg}"
        if [[ "${param}" =~ -dDOCKER_CONTAINER.* ]]; then
            __PHP_LINUX_MAPPING_DOCKER_CONTAINER=$(echo "${param}" | sed -nre 's/-dDOCKER_CONTAINER=(.*)$/\1/p')
        elif [[ "${param}" =~ -dDOCKER_TARGET_DIR.* ]]; then
            __PHP_LINUX_MAPPING_DOCKER_TARGET_DIR=$(echo "${param}" | sed -nre 's/-dDOCKER_TARGET_DIR=(.*)$/\1/p')
        elif [[ "${param}" =~ -dDOCKER_SERVER_NAME.* ]]; then
            __PHP_LINUX_MAPPING_DOCKER_SERVER_NAME=$(echo "${param}" | sed -nre 's/-dDOCKER_SERVER_NAME=(.*)$/\1/p')
        elif [[ "${param}" =~ -dDOCKER_HOST_ROOT_DIR.* ]]; then
            __PHP_LINUX_MAPPING_DOCKER_HOST_ROOT_DIR=$(echo "${param}" | sed -nre 's/-dDOCKER_HOST_ROOT_DIR=(.*)$/\1/p')
        elif [[ "${param}" =~ -dDOCKER_HOST_TARGET_ROOT_DIR.* ]]; then
            __PHP_LINUX_MAPPING_DOCKER_HOST_TARGET_ROOT_DIR=$(echo "${param}" | sed -nre 's/-dDOCKER_HOST_TARGET_ROOT_DIR=(.*)$/\1/p')
        fi
    done
}
preparseParameters "$@"
# finally environment variables takes precedence on options
if [[ ! -z "${DOCKER_CONTAINER}" ]]; then
    __PHP_LINUX_MAPPING_DOCKER_CONTAINER="${DOCKER_CONTAINER}"
fi
if [[ ! -z "${DOCKER_TARGET_DIR}" ]]; then
    __PHP_LINUX_MAPPING_DOCKER_TARGET_DIR="${DOCKER_TARGET_DIR}"
fi
if [[ ! -z "${DOCKER_SERVER_NAME}" ]]; then
    __PHP_LINUX_MAPPING_DOCKER_SERVER_NAME="${DOCKER_SERVER_NAME}"
fi
if [[ ! -z "${DOCKER_HOST_ROOT_DIR}" ]]; then
    __PHP_LINUX_MAPPING_DOCKER_HOST_ROOT_DIR="${DOCKER_HOST_ROOT_DIR}"
fi
if [[ ! -z "${DOCKER_HOST_TARGET_ROOT_DIR}" ]]; then
    __PHP_LINUX_MAPPING_DOCKER_HOST_TARGET_ROOT_DIR="${DOCKER_HOST_TARGET_ROOT_DIR}"
fi
if [[ -z "${__PHP_LINUX_MAPPING_DOCKER_SERVER_NAME}" ]]; then
    __PHP_LINUX_MAPPING_DOCKER_SERVER_NAME="trunk.${DNS_HOSTNAME}"
fi

# be sure that bash_framework bin directory exists
mkdir -p ${__PHP_LINUX_MAPPING_DOCKER_HOST_ROOT_DIR}/bin
mkdir -p ${__PHP_LINUX_MAPPING_DOCKER_HOST_TARGET_ROOT_DIR}/app

###########################################################################################
# calculate the command line
# result will be stored in:
# - PHP_PARAMS
# - ENV_VARS
# - DOCKER_CONTAINER
# - DOCKER_TARGET_DIR
###########################################################################################
function calculateCommandLine() {

    ## Usage : ${var//patternToReplace/ReplaceString}
    slash='/'
    bsl='\'

    function convertPath() {
        local path="$1"
        local baseDir="$2"

        # replace eventual \ with /
        slash='/'
        bsl='\'
        path="${path//"$bsl"/$slash}"
        if [[ "${path}" =~ [A-Za-z]: ]]; then
            # rewrite file
            path=$(cygpath -u "${path}")
        fi
        # Path mappings
        echo ${path} | sed "s#${__PHP_LINUX_MAPPING_DOCKER_HOST_TARGET_ROOT_DIR}#${baseDir}#g"
    }

    ENV_VARS+="PHP_IDE_CONFIG='serverName=${__PHP_LINUX_MAPPING_DOCKER_SERVER_NAME}' "
    ENV_VARS+="XDEBUG_CONFIG=idekey=PHPSTORM "

    # tokenize param 1 upon space
    while true
    do
        param=$(convertPath "$1" "${__PHP_LINUX_MAPPING_DOCKER_TARGET_DIR}")

        if [ "${param}" = "--configuration" ]; then
            shift
            PHP_PARAMS+=" ${param} $(convertPath "$1" "${__PHP_LINUX_MAPPING_DOCKER_TARGET_DIR}")"

        elif [ "${param}" = "--lms_instance" ]; then
            shift
            PHP_PARAMS+=" ${param}=$1"
        elif [[ "${param}" =~ -dxdebug.remote_host.* ]]; then
            # ignore
            true
        elif [[ "${param}" =~ -dDOCKER_.* ]]; then
            # ignore
            true
        elif [ "${param}" = "--filter" ]; then
            shift
            if [[ "$1" =~ /.* ]]; then
                PHP_PARAMS+=" ${param} \"$1\""
            else
                # no filter at all ?
                continue
            fi
        elif [[ "${param}" =~ ide-php(info|unit).php ]]; then
            # https://intellij-support.jetbrains.com/hc/en-us/community/posts/203368790-ide-phpunit-php-vs-phpunit
            # ide-phpunit.php is used when IDE fails to determine the version phpunit
            ideFile=$(echo "${param}" | sed -rn 's#.*(ide-.*php)$#\1#p')
            if [ -f "${param}" ]; then
                cp "${param}" "${__PHP_LINUX_MAPPING_DOCKER_HOST_TARGET_ROOT_DIR}/app/${ideFile}"
            fi
            PHP_PARAMS+=" ${__PHP_LINUX_MAPPING_DOCKER_TARGET_DIR}/app/${ideFile}"
            if [[ "${param}" =~ ide-phpunit.php ]]; then
                __PHP_LINUX_MAPPING_OUTPUT_ENABLED=1
            fi
        elif [ ! -z "${param}" ]; then
            #replace \ with \\
            bsl='\'
            param="${param//"$bsl"/$bsl$bsl}"
            # Path mappings
            param=$(echo ${param} | sed "s#${__PHP_LINUX_MAPPING_DOCKER_HOST_ROOT_DIR}#${baseDir}#g")
            PHP_PARAMS+=" ${param}"
        else
            # last argument
            break
        fi

        shift
    done

    #add specific environment variables
    for var in $(compgen -e); do
        varValue="${!var}"
        if [[ "${var}" =~ ^IDE_.+ ]]; then
            ENV_VARS+="${var}=$(convertPath "${varValue}" "${__PHP_LINUX_MAPPING_DOCKER_TARGET_DIR}") "
        fi
    done
}

if [[ "${__PHP_LINUX_MAPPING_DEBUG}" = "1" ]]; then
    # Create the destination log file that we can
    # inspect later if something goes wrong with the
    # initialization.
    touch "${__PHP_LINUX_MAPPING_LOG_FILE}"

    {
        # enable bash tracing
        set -x

        calculateCommandLine "$@"

        set +x
    } 1>>"${__PHP_LINUX_MAPPING_LOG_FILE}" 2>&1
else
    calculateCommandLine "$@"
fi

# MSYS_NO_PATHCONV=1 suppress MSYS path translation
declare cmd
exec 3>&1
exec 4>&2
cmd=(docker exec --user=${CONTAINER_USER} "${__PHP_LINUX_MAPPING_DOCKER_CONTAINER:-bash_framework-web}" bash -c $"source /home/www-data/.bashrc && ${ENV_VARS} exec php ${PHP_PARAMS}")
if [[ "${__PHP_LINUX_MAPPING_OUTPUT_ENABLED}" = "1" ]]; then
    echo "MSYS_NO_PATHCONV=1 exec ${cmd[*]}"
fi
if [[ "${__PHP_LINUX_MAPPING_DEBUG}" = "1" ]]; then
    echo "MSYS_NO_PATHCONV=1 exec ${cmd[*]}" >>"${__PHP_LINUX_MAPPING_LOG_FILE}"
fi

MSYS_NO_PATHCONV=1 exec "${cmd[@]}"
