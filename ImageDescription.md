# ReleaseNotes

# Description
Base image for running docker and php/javascript in dev mode

## Image content
This images contains:
 - docker/docker-compose
 - git
 - vim
 - Jetbrains toolbox
 - chrome/firefox
 - open office
 - npm + prettier

## Special features
Special features:
  - apt daily updates disabled
  - release upgrader disabled
  - IPv6 enabled as chrome dev tools need it
  - windows management : unity
  - Server X enabled
  - screen lock disabled
  - keyboard fr automatically configured
  - sleep mode disabled
  - ntp disabled
  - hibernate enabled
  - inotify limit raised so phpstorm can be refreshed automatically when files are changing
  
## Desktop manager
${imageDesktopDesc}

# Releases
## V1.0.5
Release Date: 2019-11-04
Added:
  - added linters (sass-lint stylelint), formatters (prettier) and code sniffers (phpmd, php-cs-fixer, phpcbf)
  - npm/composer usable by vagrant user (not root)

## V1.0.4
Release Date: 2019-10-10
Added:
  - activate ipv6 as needed by google chrome dev tools

## V1.0.3
Release Date: 2019-09-09
Added:
  - Visual studio code

## V1.0.2
Release Date: 2019-09-09
Changes:
 - one image by desktop manager (gnome, lxde)

## V1.0.1
Release Date: 2019-09-05
Changes:
 - replaced phpstorm install with jetbrains toolbox

## V1.0.0
Release Date: 2019-09-04
Base version 

# FAQ
## Configure your keyboard if not fr
launch these commands:

<pre>
    dpkg-reconfigure keyboard-configuration
    service keyboard-setup restart
</pre>
