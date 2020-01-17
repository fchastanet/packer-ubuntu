#!/usr/bin/env bash

DEBUG=0
if [[ "${DEBUG}" = "1" ]]; then
    LOG_FILE="${HOME}/script.log"

    # Create the destination log file that we can
    # inspect later if something goes wrong with the
    # initialization.
    touch "${LOG_FILE}"

    # Open standard out at `$LOG_FILE` for write.
    # This has the effect
    exec 1>"${LOG_FILE}"

    # Redirect standard error to standard out such that
    # standard error ends up going to wherever standard
    # out goes (the file).
    exec 2>&1

    echo $1
fi

# be sure that parameters are not interpreted by bash
set -o noglob

# tokenize param 1 upon space
set -- $1
PARAMS=()

while true; do
    param="$1"
    if [ "${param}" = "--filter" ]; then
        shift
        if [[ "$1" =~ /.* ]]; then
            filter="$1"
            # a filter that begin with /, parse next params until end slash
            while true
            do
                shift
                filter+=" $1"
                if [[ "$1" =~ .*/ ]]; then
                    PARAMS+=("${param} \"${filter}\"")
                    shift
                    break;
                fi
            done
            continue
        else
            # no filter at all ?
            continue
        fi
     elif [ -z "${param}" ]; then
        # last argument
        break
     fi
     PARAMS+=("${param}")
     shift
done

curDir=$( cd "$( readlink -e "${BASH_SOURCE[0]%/*}" )" && pwd )
if [[ "${DEBUG}" = "1" ]]; then
    echo "${curDir}/phpLinuxMapping.sh" "${PARAMS[@]}"
fi
exec "${curDir}/phpLinuxMapping.sh" "${PARAMS[@]}"