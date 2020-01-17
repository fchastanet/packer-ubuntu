#!/usr/bin/env bash

File::extractTar() {
    local fromDir=$1
    local file=$2
    local result=1

    local fromDirType
    fromDirType=$(cd ${fromDir} && until last=$(findmnt ${PWD} -o FSTYPE -n) ; do cd .. ; done &&  echo ${last} )

    # in order to capture stderr into a variable
    # we need to redirect error to stdout and stdout to err
    # great doc: http://www.catonmat.net/blog/bash-one-liners-explained-part-three/
    local errors
    errors=$( \
        cd "${fromDir}" &&\
        tar xz --checkpoint=.100 -f "${file}" 3>&1 1>&2 2>&3 3>&- | \
        if [ "${fromDirType}" = "cifs" ]; then \
            # when filesystem is cifs (windows share), we have to ignore some errors
            grep -v  -e "Can't restore time" \
               -e "tar: Error exit delayed from previous errors." \
               -e "Cannot utime: Operation not permitted" \
               -e "tar: Exiting with failure status due to previous errors" \
               -e "Directory renamed before its status could be extracted"; \
        else grep -v -e "${fromDir}"; fi \
        && cd - || return \
    )

    # if errors is empty everything is OK
    [[ -z ${errors} ]] && result=0

    [[ ! -z ${errors} ]] && Log::displayError "errors while untarring ${file} : ${errors}"

    return ${result}
}


# retrieve all the directories that contains a given file
# @param $1 directory to scan
# @param $2 expected file to find
# @param $3 variable in which the result array will be written
File::getDirectoriesThatContainsFile() {
    local dir="$1"
    local expectedFile="$2"
    local -n myArray=$3              # use nameref for indirection

    # SC2034 myArray is dereferenced
    # shellcheck disable=2034
    readarray -t myArray < <(find "${dir}" -name "${expectedFile}" -printf "%h\n" | sed -r 's|/[^/]+$||' | sort -u)
}


File::copyFilesToDir() {
    local targetDir="$1"
    local ownerUser="$2"
    local ownerGroup="$3"
    local -a sourceFiles=("${@:4}")

    if [[ -z "${sourceFiles[*]}" ]]; then
        # no file to copy
        return 1
    fi

    # copy configuration files (only if configuration is not a mounted drive)
    if [[ "$(mount | grep "${targetDir}" | wc -l)" = "0" ]]; then
        Log::displayInfo "Copying files ${sourceFiles[*]} to ${targetDir}"
        cp -t "${targetDir}" ${sourceFiles[*]}
        File::chownRecursive "${targetDir}" "${ownerUser}" "${ownerGroup}"
    fi
}

# @param $1 directory to check
# @return 0 if directory is empty
File::isDirectoryEmpty() {
    local dir="$1"
    if [[ ! -d "${dir}" ]] || [[ $( ls -A "${dir}" | wc -l) = 0 ]] ; then
        return 0
    else
        return 1
    fi
}

File::chownRecursive() {
    local dir="$1"
    local user="$2"
    local group="$3"

    find "${dir}" \( ! -user "${user}" -o ! -group "${group}" \) -print0 | xargs --no-run-if-empty -0 chown "${user}":"${group}"
}

readonly __rsyncExcludeCvs=0
readonly __rsyncIncludeCvs=1

readonly __rsyncDelete=0
readonly __rsyncNoDelete=1

readonly __directionFromToDir=0
readonly __directionToFromDir=1

File::syncDirectories() {
    local fromBaseDir="$1"
    local relativeDir="$2"
    local toDir="$3"
    local message="$4"
    local excludeCvs=$5
    local delete=$6
    local direction=$7
    local -a rsyncOptions

    Log::displayInfo "${message} FROM ${fromBaseDir}/${relativeDir} to ${toDir}/${relativeDir}"
    if [[ ! -d "${toDir}/${relativeDir}" ]]; then
        mkdir -p "${toDir}/${relativeDir}" || exit 1
    fi
    chown -f ${CONTAINER_USER}:${CONTAINER_GROUP} "${toDir}/${relativeDir}"

    rsyncOptions=("--info=progress2" "-rltz" "--human-readable")
    if [[ "${delete}" = "${__rsyncDelete}" ]]; then
        rsyncOptions+=("--delete")
    fi
    if [[ "${excludeCvs}" = "${__rsyncIncludeCvs}" ]]; then
        rsyncOptions+=("--cvs-exclude")
    fi

    if [[ "${direction}" = "${__directionFromToDir}" ]]; then
        Log::displayDebug "rsync ${rsyncOptions[*]} ${fromBaseDir}/${relativeDir} ${toDir}"
        rsync ${rsyncOptions[*]} "${fromBaseDir}/${relativeDir}" "${toDir}"
    else
        Log::displayDebug "rsync ${rsyncOptions[*]} ${toDir}/${relativeDir} ${fromBaseDir}"
        rsync ${rsyncOptions[*]} "${toDir}/${relativeDir}" "${fromBaseDir}"
    fi
}