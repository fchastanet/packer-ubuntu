#!/usr/bin/env bash

#
# @param sourceDir the directory in which the reo should be cloned
# @param repo the git repository to clone
GitCloneOrPull::installRepo() {
    local checkFile="$1"
    local sourceDir="$2"
    local repo="$3"

    System::expectNonRootUser

    # if git process has been interrupted(docker-compose interrupted), remove git lock file
    rm -f "${sourceDir}/.git/index.lock" 2>/dev/null || true

    if [[ ! -d "${sourceDir}/.git" ]]; then
      Log::displayInfo "******************************************************"
      Log::displayInfo "Checkout ${sourceDir} ..."
      git clone "${repo}" "${sourceDir}" || {
        Log::displayError "The GIT clone has failed, please copy your SSH keys in ${bootstrapSingleton['HOST_HOME']}/.ssh/."
        exit 1
      }
    fi

    # keep updated!
    Log::displayInfo "Update ${sourceDir} ..."
    (
        cd ${sourceDir} || exit 1
        git checkout . || {
            Log::displayError "GIT checkout has failed."
            exit 1
        }

        local result
        result=$(git pull 2>&1 ; echo " result=$?")

        [[ "${result}" =~ result=0 ]] || {
            Log::displayError "GIT pull has failed."
        }
    )
}
