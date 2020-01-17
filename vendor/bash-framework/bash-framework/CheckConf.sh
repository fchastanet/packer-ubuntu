#!/usr/bin/env bash

# install if needed
# @param confFileToCheck
# @param confFileChecksum
# @param installHandler function to call if confFileChecksum is not present or different that checksum of confFileToCheck
# @param configCheckFileHasNotChangedHandler function to call if confFileChecksum is present and not modified
CheckConf::ifChecksum() {
    local confFileToCheck="$1"
    local confFileChecksum="$2"
    local installHandler="$3"
    local configCheckFileHasNotChangedHandler=""
    local checksumHandler=""
    local result=0

    if [[ ! -z "${4+x}" ]]; then
        configCheckFileHasNotChangedHandler="$4"
    fi

    if [[ ! -z "${5+x}" && ! -z "$5" ]]; then
        checksumHandler="$5"
    else
        localChecksumHandler() {
            local file="$1"
            md5sum "${file}" | awk '{ print $1 }'
        }
        checksumHandler=localChecksumHandler
    fi

    md5=$(${checksumHandler} "${confFileToCheck}")
    oldMd5=''
    if [[ -f "${confFileChecksum}" ]]; then
        oldMd5=`cat "${confFileChecksum}"`
    fi

    # if the checksum file does not exists or different, update of vendor will be done
    if [[ "${oldMd5}" != "${md5}" ]]; then
        Log::displayWarning "file ${confFileToCheck} has changed, ensure your parameters are correct"
        # call installer and don't fails right if it fails
        ${installHandler} "${confFileToCheck}" "${confFileChecksum}" "$(dirname "${confFileToCheck}")"
        result=$?

        if [[ "${result}" = "0" ]]; then
            echo "${md5}" > "${confFileChecksum}"
        fi
    else
        Log::displayDebug "${confFileToCheck} has not changed - install avoided"
        if [[ ! -z "${configCheckFileHasNotChangedHandler}" ]]; then
            ${configCheckFileHasNotChangedHandler} "${confFileToCheck}" "${confFileChecksum}"
        fi
    fi

    return ${result}
}

# install if checksum does not exists or is older than specified value or checksum has changed
# @param checksumFileReference the file on which checksum will be calculated
# @param confFileChecksum the path of the checksum file
# @param expirationPeriod if checksum created before this period, then consider it expired (eg: 2 days ago)
#          format available here : https://www.gnu.org/software/coreutils/manual/html_node/Examples-of-date.html
# @param installHandler function to call if confFileChecksum is not present
# @param checksumFileChangedHandler function to call if confFileChecksum has changed
# @param checksumFileExpiredHandler function to call if confFileChecksum has expired
CheckConf::ifChecksumExpires() {
    local checksumFileReference="$1"
    local confFileChecksum="$2"
    local expirationPeriod="$3"
    local installHandler="$4"
    local checksumFileChangedHandler="$5"
    local checksumFileExpiredHandler="$6"
    local result=0

    if [[ -f "${checksumFileReference}" ]] && [[ -f "${confFileChecksum}" ]]; then
        local md5
        md5=$(md5sum "${checksumFileReference}" | awk '{ print $1 }')
        local oldMd5
        oldMd5=`cat "${confFileChecksum}"`

        if [ "${oldMd5}" != "${md5}" ]; then
            # the checksum file is different than existing one
            ${installHandler} "${checksumFileReference}" "${confFileChecksum}" "${expirationPeriod}"
            result=$?

            if [ "${result}" = "0" ]; then
                echo "${md5}" > "${confFileChecksum}"
            fi
        else
            # the checksum file has not changed, check expiration date
            # checksum date with format 2018-10-30 21:12:11
            local conFileChecksumCreationDate
            conFileChecksumCreationDate=$(stat "${confFileChecksum}" --printf "%y"|cut -f1 -d".")

            # expiration period
            local expirationDate
            expirationDate=$(date --date="${expirationPeriod}" +"%Y-%m-%d %H:%m:%S")

            if [[ "${expirationDate}" > "${conFileChecksumCreationDate}" ]]; then
                ${checksumFileExpiredHandler} "${checksumFileReference}" "${confFileChecksum}" "${expirationPeriod}"
                result=$?

                if [ "${result}" = "0" ]; then
                    echo "${md5}" > "${confFileChecksum}"
                fi
            fi
        fi
    else
        # checksum file or checksum file reference does not exist
        ${checksumFileChangedHandler} "${checksumFileReference}" "${confFileChecksum}" "${expirationPeriod}"
        result=$?

        if [ "${result}" = "0" ]; then
            md5=$(md5sum "${checksumFileReference}" | awk '{ print $1 }')
            echo "${md5}" > "${confFileChecksum}"
        fi
    fi

    return ${result}
}

# check if vendor dir exists
# @param baseDir
# @param vendorDir
# @param confFileChecksumName
# @param installHandler function to call if vendorDir does not exists or is empty
CheckConf::ifInitialized() {
    local baseDir="$1"
    local vendorDir="$2"
    local confFileChecksumName="$3"
    local installHandler="$4"

    local result=0

    # shellcheck disable=2010
    if  \
        [[ ! -d "${vendorDir}" ]] || \
        [[ $( ls -A "${vendorDir}" | grep -v "${confFileChecksumName}" | wc -l) = 0 ]] \
    ; then
        # call installer and don't fails right if it fails
        ${installHandler} "${baseDir}" "${vendorDir}" "${confFileChecksumName}"
        result=$?
    fi

    return ${result}
}

CheckConf::compareChanges() {
    local fromTempFile="$1"
    local fromRealFileName="$2"
    local toTempFile="$3"
    local toRealFileName="$4"

    local screenColsWidth
    local diffWidth
    local length
    local diff

    screenColsWidth=$(tput cols)

    diff=$(sdiff -w ${screenColsWidth} --ignore-blank-lines --suppress-common-lines "${fromTempFile}" "${toTempFile}" || true)
    if [[ -z "${diff}" ]]; then
        echo ""
        return
    fi

    diffWidth=$(( ${screenColsWidth:-80} / 2 ))
    length=$(( ${diffWidth} - ${#fromRealFileName} - 1 ))
    printf "%s %$((length - 2))s %s %s\n" "${fromRealFileName}" '' $'\u25c0' "${toRealFileName}"
    eval printf %.0s- '{1..'"$(( diffWidth - 2 ))"\}; echo -n $' \u25c0 '; eval printf %.0s- '{1..'"$(( diffWidth - 3 ))"\}; echo
    echo "${diff}"
}

CheckConf::createOrUpdateConf() {
    local confTemplateFile="$1"
    local confFile="$2"
    local compareChangesHideCommonFolder="$3"
    local generateConf="$4"
    local generateConfForComparison="$5"
    local checksumHandler=""
    local overwriteConfFile=${__bash_framework__choice_ignore}

    if [[ ! -z "${6+x}" ]]; then
        checksumHandler="$6"
    fi

    function confHasChanged() {
        # if env file exist, display a warning
        if [[ -f "${confFile}" ]]; then
            # check differences between env files
            ${generateConfForComparison} \
                "${confTemplateFile}" \
                "/tmp/confFileTemplate" \
                "${confFile}" \
                "/tmp/confFile" \
                ${generateConf}

            local diff
            diff=$(CheckConf::compareChanges \
                "/tmp/confFile"         "${confFile#*${compareChangesHideCommonFolder}/}"         \
                "/tmp/confFileTemplate" "${confTemplateFile#*${compareChangesHideCommonFolder}/}")
            if [[ -z "${diff}" ]]; then
                Log::displayDebug "changes detected but finally no diff changes"
                overwriteConfFile="${__bash_framework__choice_overwrite}"
            else
                echo "${diff}"
                UI::askToIgnoreOverwriteAbort || overwriteConfFile=$?
            fi
        fi

        # if file doesn't exist or ignore diff with template file, create it or overwrite file
        if [[ "${overwriteConfFile}" = "${__bash_framework__choice_overwrite}" ||  ! -f "${confFile}" ]]; then
            if [[ -f "${confFile}" ]]; then
                Log::displayInfo "File ${confFile}.backup created"
                cp "${confFile}" "${confFile}.backup"
            fi
            ${generateConf} "${confTemplateFile}" "${confFile}"
            Log::displayInfo "File ${confFile} created, please check that parameters are correct"
        fi
    }
    if [[ ! -f "${confFile}" ]]; then
        confHasChanged
    else
        CheckConf::ifChecksum \
            "${confTemplateFile}" \
            "${confTemplateFile}.checksum" \
            confHasChanged \
            "" \
            "${checksumHandler}"
    fi
}