#!/usr/bin/env bash

declare -ag __bash_framework__importedFiles

System::expectEnvFile() {
    if [ ! -f "${__rootSrcPath__}/.env" ]; then
        echo 'you have to run `make configure` before running this command'
        exit 1
    fi
}

System::expectUser() {
    local expectedUserName="$1"
    local currentUserName

    currentUserName=$(id -u -n)
    if [  "${currentUserName}" != "${expectedUserName}" ]; then
        Log::displayError "The script must be run as ${expectedUserName}"
        exit 1
    fi
}

System::expectNonRootUser() {
    local expectedUserName="$1"
    local currentUserName

    currentUserName=$(id -u -n)
    if [  "${currentUserName}" = "root" ]; then
        Log::displayError "The script must not be run as root"
        exit 1
    fi
}

System::expectGlobalVariables() {
    for var in "${@}"
    do
        [[ -v "${var}" ]] || {
            Log::displayError "Variable ${var} is unset"
            exit 1
        }
    done
}

System::GetAbsolutePath() {
  # http://stackoverflow.com/questions/3915040/bash-fish-command-to-print-absolute-path-to-a-file
  # $1 : relative filename
  local file="$1"
  if [[ "$file" == "/"* ]]
  then
    echo "$file"
  else
    echo "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  fi
}

System::WrapSource() {
  local libPath="$1"
  shift

  builtin source "$libPath" "$@" || {
    Log::displayError "Unable to load $libPath"
    exit 1
  }
}

System::SourceFile() {
  local libPath="$1"
  shift

  [[ ! -f "$libPath" ]] && return 1 # && e="Cannot import $libPath" throw

  libPath="$(System::GetAbsolutePath "$libPath")"

  # [ -e "$libPath" ] && echo "Trying to load from: ${libPath}"
  if [[ -f "$libPath" ]]
  then
    ## if already imported let's return
    # if declare -f "Array::Contains" &> /dev/null &&
    if [[ "${__bash_framework__allowFileReloading-}" != true ]] && [[ ! -z "${__bash_framework__importedFiles[*]}" ]] && Array::Contains "$libPath" "${__bash_framework__importedFiles[@]}"
    then
      # DEBUG subject=level3 Log "File previously imported: ${libPath}"
      return 0
    fi

    # DEBUG subject=level2 Log "Importing: $libPath"

    __bash_framework__importedFiles+=( "$libPath" )
    System::WrapSource "$libPath" "$@"

  else
    :
    # DEBUG subject=level2 Log "File doesn't exist when importing: $libPath"
  fi
}

System::SourcePath() {
  local libPath="$1"
  shift
  # echo trying $libPath
  if [[ -d "$libPath" ]]
  then
    local file
    for file in "$libPath"/*.sh
    do
      System::SourceFile "$file" "$@"
    done
  else
    System::SourceFile "$libPath" "$@" || System::SourceFile "${libPath}.sh" "$@"
  fi
}

System::ImportOne() {
  local libPath="$1"
  shift

  # try local library
  # try vendor dir
  # try from project root
  # try absolute path
  {
    local localPath="${__rootVendorPath}"
    localPath="${localPath}/${libPath}"
    System::SourcePath "${localPath}" "$@"
  } || \
  System::SourcePath "${__rootVendorPath}/${libPath}" "$@" || \
  System::SourcePath "${__rootSrcPath__}/${libPath}" "$@" || \
  System::SourcePath "${libPath}" "$@" || \
  {
    Log::displayError "Cannot import $libPath"
    exit 1
  }
}

System::Import() {
  local savedOptions
  case $- in
  (*x*) savedOptions='set -x'; set +x;;
  (*) savedOptions='';;
  esac
  local libPath
  for libPath in "$@"
  do
    System::ImportOne "$libPath"
  done
  { eval "${savedOptions}";} 2> /dev/null
}

#TODO check also https://github.com/niieani/bash-oo-framework/blob/master/lib/util/type.sh
System::VarType() {
    local var=$( declare -p $1 2> /dev/null || true)
    local reg='^declare -n [^=]+=\"([^\"]+)\"$'
    while [[ $var =~ $reg ]]; do
            var=$( declare -p ${BASH_REMATCH[1]} )
    done

    case "${var#declare -}" in
    a*)
            echo "ARRAY"
            ;;
    A*)
            echo "HASH"
            ;;
    i*)
            echo "INT"
            ;;
    x*)
            echo "EXPORT"
            ;;
    *)
            echo "OTHER"
            ;;
    esac
}