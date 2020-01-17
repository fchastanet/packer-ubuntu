@echo off

REM this file must be used as entrypoint for phpstorm
REM

setlocal ENABLEDELAYEDEXPANSION

REM get current dir
SET CHANGE_PATH_COMMAND="cygpath -u %~dp0"
SET PHP_WINDOWS_MAPPING_PATH=/data/bash_framework/.dev/tools/
REM complicated batch command to get the result of CHANGE_PATH_COMMAND into PHP_WINDOWS_MAPPING_PATH
FOR /F "usebackq delims=" %%i IN (`%CHANGE_PATH_COMMAND%`) DO SET PHP_WINDOWS_MAPPING_PATH=%%~i

REM transform all the parameters of the command into one string
SET params=%*
SET params=!params:"=!
SET TO_RUN=sh --login -c "%PHP_WINDOWS_MAPPING_PATH%phpWindowsMapping.sh '%params%'"

call !TO_RUN!

