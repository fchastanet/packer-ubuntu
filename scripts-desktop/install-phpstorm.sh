#!/usr/bin/env bash

set -x
# requirement : desktop.sh

set -o errexit
set -o pipefail
shopt -s nullglob

apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    jq \
    wget

HOME="/home/vagrant"
DROPBOX_PATH="$HOME/Dropbox"
INSTALL_PATH="/opt/PhpStorm"
TEMP_PATH="/tmp/.tmp"
EXECUTABLE_PATH="$INSTALL_PATH/bin/phpstorm.sh"

# Installing the application
rm -Rf $INSTALL_PATH
rm -Rf $TEMP_PATH
mkdir -p $TEMP_PATH

URL=$(wget -O - "https://data.services.jetbrains.com/products/releases?code=PS&latest=true&type=release" 2> /dev/null | jq '.PS[] | .downloads | .linux | .link' | tr -d '"')

wget -O - "${URL}" | tar xzf - -C $TEMP_PATH
mv $TEMP_PATH/PhpStorm-* $INSTALL_PATH
rm -Rf $TEMP_PATH

# Creating a symlink for user settings directory
# stored in DropBox
files=($DROPBOX_PATH/.WebIde*)
for file in "${files[@]}" ; do
    ln -s $file $HOME/ || true
done

# Creating a desktop launcher
mkdir -p /home/vagrant/.local/share/applications
echo "
[Desktop Entry]
Type=Application
Name=PhpStorm
Icon="$INSTALL_PATH/bin/phpstorm.png"
Exec=$EXECUTABLE_PATH
Terminal=false
">/home/vagrant/.local/share/applications/phpstorm.desktop
chown -R vagrant:vagrant /home/vagrant/.local
