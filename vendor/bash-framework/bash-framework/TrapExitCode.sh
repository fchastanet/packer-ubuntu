#!/usr/bin/env bash

import bash-framework/Log

let TRAPPED_COUNT=1
Trap::exit() {
    local exitCode=$?
    if [[ ${exitCode} = 0 ]]; then
        exit 0
    fi

    Log::displayError "${CONTAINER_NAME:-this} container exits abnormally"
    ((TRAPPED_COUNT++))
    if [[ "${DOCKER_ENTRYPOINT_DEBUG}" = "1" ]]; then
        if [[ ${TRAPPED_COUNT} -gt 1 ]]; then
            Log::displayDebug "up and sleeping."
            sleep 9999d
        fi
    fi

    if [[ "${exitCode}" != "0" ]]; then
        Log::displayError "Exit with code ${exitCode}"
        # something bad happens, next time we will check again softwares availability
        rm -f "${__rootSrcPath__}/.dev/.docker/configChecked.checksum" || true
    fi

    exit ${exitCode}
}

trap Trap::exit EXIT

Trap::error() {
    local script="${BASH_SOURCE[1]#./}"
    local line="$1"
    Log::displayError "script error at ${script}(${line})"
}
trap 'Trap::error $LINENO' ERR

Trap::abort() {
    Log::displayError "${CONTAINER_NAME:-this} container exits abnormally"
    # something bad happens, next time we will check again softwares availability
    rm -f "${__rootSrcPath__}/.dev/.docker/configChecked.checksum" || true
}

#HUP - Hang Up. The controlling terminal has gone away.
#INT - Interrupt. The user has pressed the interrupt key (usually Ctrl-C or DEL).
#QUIT - Quit. The user has pressed the quit key (usually Ctrl-\). Exit and dump core.
#KILL - Kill. This signal cannot be caught or ignored. Unconditionally fatal. No cleanup possible.
#TERM - Terminate. This is the default signal sent by the kill command.
#EXIT - Not really a signal. In a shell script, an EXIT trap is run on any exit, signalled or not.
trap Trap::trapAbort HUP TERM