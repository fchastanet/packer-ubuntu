#!/usr/bin/env bash


import bash-framework/Log

declare -g __db_mysqlOptions=""
declare -g __db_mysqlDefaultQueryOptions="-s --skip-column-names"
declare -g __db_mysqlQueryOptions="${__db_mysqlDefaultQueryOptions}"
declare -g __db_mysqldumpOptions="--compress --compact --hex-blob --routines --triggers --single-transaction"
declare -g __db_mysqlAuthFile
declare -g __db_mysqlCommandPrefix=""

Database::setMysqlPrefix() {
    __db_mysqlCommandPrefix="$1"
}
Database::setMysqlOptions() {
    __db_mysqlOptions="--default-character-set=utf8 $1"
}
Database::setMysqlDumpOptions() {
    __db_mysqldumpOptions="--default-character-set=utf8 $1"
}
Database::setMysqlQueryOptions() {
    __db_mysqlQueryOptions="$1"
}
Database::restoreMysqlQueryOptions() {
    __db_mysqlQueryOptions="${__db_mysqlDefaultQueryOptions}"
}

__DATABASE_BIN_PATH="/usr/bin"

Database::createAuthFile() {
    local mysqlHostName="$1"
    local mysqlHostPort="$2"
    local user="$3"
    local passwd="$4"

    __db_mysqlAuthFile=$(mktemp "${TMPDIR:-/tmp/}/mysql.XXXXXXXXXXXX.cnf")

    rm -f "${__db_mysqlAuthFile}" 2>/dev/null || true
    local conf=""
    conf+="[client]\n"
    conf+="user = ${user}\n"
    conf+="password = ${passwd}\n"
    conf+="host = ${mysqlHostName}\n"
    conf+="port = ${mysqlHostPort}\n"

    printf "%b" "${conf}" > "${__db_mysqlAuthFile}"

    #trap "rm -f "${__db_mysqlAuthFile}" 2>/dev/null" EXIT
}
# check if database exists
Database::ifDbExists() {
    local mysqlHostName="$1"
    local mysqlHostPort="$2"
    local rootUser="$3"
    local rootPasswd="$4"
    local dbName="$5"
    local result
    local mysqlCommand=""

    System::expectNonRootUser

    Database::createAuthFile "${mysqlHostName}" "${mysqlHostPort}" "${rootUser}" "${rootPasswd}"

    mysqlCommand="${__DATABASE_BIN_PATH}/mysqlshow --defaults-extra-file="${__db_mysqlAuthFile}" "${dbName}" | grep -v Wildcard | grep -o "${dbName}""
    Log::displayDebug "execute command: '${mysqlCommand}'"
    result=$(MSYS_NO_PATHCONV=1 eval "${mysqlCommand}")
    if [ "${result}" = "${dbName}" ]; then
        return 0
    fi
    return 1
}

# check if table propel_migration on db $1 exists
# @return 0 if propel_migration table exists, 1 else
Database::ifDbInitialized() {
    local mysqlHostName="$1"
    local mysqlHostPort="$2"
    local rootUser="$3"
    local rootPasswd="$4"
    local dbName="$5"
    local tableThatShouldExists="${6:-propel_migration}"
    local result

    System::expectNonRootUser

    local sql=$"select count(*) from information_schema.tables where table_schema=\"${dbName}\" and table_name=\"${tableThatShouldExists}\""
    result=$(Database::query "${mysqlHostName}" "${mysqlHostPort}" "${rootUser}" "${rootPasswd}" "${sql}")
    if [[ "${result}" = "0" ]]; then
        Log::displayWarning "Db ${dbName} not initialized"
        return 1
    fi
    Log::displayInfo "Db ${dbName} already initialized"
    return 0
}

# create database if not exists
Database::createDb() {
    local mysqlHostName="$1"
    local mysqlHostPort="$2"
    local rootUser="$3"
    local rootPasswd="$4"
    local dbName="$5"
    local result

    System::expectNonRootUser

    local sql="CREATE DATABASE IF NOT EXISTS ${dbName} CHARACTER SET 'utf8' COLLATE 'utf8_general_ci'"
    Database::query "${mysqlHostName}" "${mysqlHostPort}" "${rootUser}" "${rootPasswd}" "${sql}"
    local result=$?

    if [[ "${result}" = "0" ]]; then
        Log::displayInfo "Db ${dbName} has been created"
    else
        Log::displayError "Creating Db ${dbName} has failed"
    fi
    return ${result}
}

# create database if not exists
Database::dropDb() {
    local mysqlHostName="$1"
    local mysqlHostPort="$2"
    local rootUser="$3"
    local rootPasswd="$4"
    local dbName="$5"

    System::expectNonRootUser
    local sql="DROP DATABASE ${dbName}"
    Database::query "${mysqlHostName}" "${mysqlHostPort}" "${rootUser}" "${rootPasswd}" "${sql}"
    local result=$?

    if [[ "${result}" = "0" ]]; then
        Log::displayInfo "Db ${dbName} has been dropped"
    else
        Log::displayError "Dropping Db ${dbName} has failed"
    fi
    return ${result}
}

# query mysql on a given db
#
# param 5 sql
#    if not provided or empty, the command can be piped (eg: cat file.sql | Database::queryDb ...)
# param 6 (optional) the db name
Database::query() {
    local mysqlHostName="$1"
    local mysqlHostPort="$2"
    local user="$3"
    local passwd="$4"
    local mysqlCommand=""

    System::expectNonRootUser

    if [[ ! -z "${__db_mysqlCommandPrefix}" ]]; then
        mysqlCommand="${__db_mysqlCommandPrefix} "
    fi

    Database::createAuthFile "${mysqlHostName}" "${mysqlHostPort}" "${user}" "${passwd}"

    mysqlCommand+="${__DATABASE_BIN_PATH}/mysql --defaults-extra-file="${__db_mysqlAuthFile}" ${__db_mysqlQueryOptions} ${__db_mysqlOptions}"
    # add optional db name
    if [[ ! -z "${6+x}" ]]; then
        mysqlCommand+=" "$6""
    fi
    # add optional sql query
    if [[ ! -z "${5+x}" && ! -z "$5" ]]; then
        if [[ ! -f "$5" ]]; then
            mysqlCommand+=" -e "
            mysqlCommand+=$(Functions::quote "$5")
        fi
    fi
    Log::displayDebug "execute command: '${mysqlCommand}'"

    if [[ -f "$5" ]]; then
        eval "${mysqlCommand}" < "$5"
    else
        eval "${mysqlCommand}"
    fi
    local result="$?"

    # ensure default query options are restored each time
    Database::restoreMysqlQueryOptions

    return ${result}
}

Database::dump() {
    local mysqlHostName="$1"
    local mysqlHostPort="$2"
    local user="$3"
    local passwd="$4"
    local db="$5"
    local optionalTableList=""
    local dumpAdditionalOptions=""
    local mysqlCommand=""

    System::expectNonRootUser

    # optional table list
    shift 5
    if [[ ! -z "${1+x}" ]]; then
        optionalTableList="$1"
        shift 1
    fi

    # additional options
    if [[ ! -z "${1+x}" ]]; then
        dumpAdditionalOptions="$@"
    fi

    Database::createAuthFile "${mysqlHostName}" "${mysqlHostPort}" "${user}" "${passwd}"

    if [[ ! -z "${__db_mysqlCommandPrefix}" ]]; then
        mysqlCommand="${__db_mysqlCommandPrefix} "
    fi
    mysqlCommand+="${__DATABASE_BIN_PATH}/mysqldump --defaults-extra-file="${__db_mysqlAuthFile}" ${__db_mysqldumpOptions} ${dumpAdditionalOptions} ${db} ${optionalTableList}"

    Log::displayDebug "execute command: '${mysqlCommand}'"
    eval "${mysqlCommand}"
    return $?
}