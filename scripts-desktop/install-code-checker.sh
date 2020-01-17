#!/usr/bin/env bash

set -o errexit
set -o pipefail
shopt -s nullglob

set -x

# install node 13
curl -sL https://deb.nodesource.com/setup_13.x | bash -
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    nodejs

# Install code checkers
# needed by php code sniffer: php-mbstring
# needed by composer : php-xml
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    composer \
    php-mbstring \
    php-xml \
    shellcheck

# configure composer to be run as vagrant user
mkdir -p /usr/local/.composer
chown vagrant:vagrant /usr/local/.composer
sed -i -rn 's#PATH="([^"]+)"$#PATH="\1:/usr/local/.composer/vendor/bin"#p' /etc/environment
source /etc/environment
# TODO do the same in bootstrap
sudo -H -u vagrant bash -c "ln -s /usr/local/.composer /home/vagrant/.composer"
ln -s /usr/bin/composer /usr/local/bin/composer

# configure node / npm to be run as vagrant user
sed -i -rn 's#PATH="([^"]+)"$#PATH="\1:/usr/lib/npm/bin"#p' /etc/environment
echo 'NODE_PATH="/usr/lib/npm/node_modules"' >> /etc/environment
mkdir -p /usr/lib/npm/node_modules /usr/lib/npm/npm_cache
chown -R vagrant:vagrant /usr/lib/npm
CMD="source /etc/environment && "
CMD="npm config set prefix /usr/lib/npm && "
CMD+="npm config set cache /usr/lib/npm/npm_cache"
sudo -H -u vagrant bash -c "${CMD}"

# linters
NODE_MODULES=(
    prettier
    sass-lint
    stylelint
)
CMD="npm install -g "
CMD+="${NODE_MODULES[@]}"

# php code sniffers
CMD+=' && composer global require "squizlabs/php_codesniffer=*"'
CMD+=' && composer global require "phpmd/phpmd=*"'
CMD+=' && composer global require "friendsofphp/php-cs-fixer=*"'

sudo -H -u vagrant bash -c "${CMD}"

