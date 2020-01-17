#!/bin/bash

[[ "$(id -u)" != "0" ]] && exec sudo "$0" "$@"
echo -e " \e[94mInstalling Visual Studio Code\e[39m"
echo ""

curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" \
    > /etc/apt/sources.list.d/vscode.list

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    apt-transport-https

DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    code

echo  -e "\e[32mDone.\e[39m"
