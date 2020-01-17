#!/bin/bash
set -x
# this script will set common configuration for any desktop manager used
if [[ "$DESKTOP" = "serverX11" ]]; then
  exit 0
fi

set -o errexit
set -o pipefail
shopt -s nullglob

SSH_USER=${SSH_USERNAME:-vagrant}

echo "==> common desktop configuration"

echo "==> create /usr/local/bin/desktop-custom-configure file"
cat <<- EOF > /usr/local/bin/desktop-custom-configure
#!/bin/bash

# xset -dpms s off s noblank s 0 0 s noexpose
# disable screen saver
xset s off &

# prevent the display from blanking
xset s noblank &

# prevent the monitor's DPMS energy saver from kicking in
xset -dpms &

# disable lock screen
gsettings set org.gnome.desktop.lockdown disable-lock-screen 'true' &

# disable screen blackout. This stops the shield but means the monitor remains permanently on (fixed by DPMS below)
gsettings set org.gnome.desktop.session idle-delay 0 &

# Disable gnome power plugin (this plugin will always disable the DPMS timeouts you set below)
gsettings set org.gnome.settings-daemon.plugins.power active false &

# enable num lock
gsettings set org.gnome.settings-daemon.peripherals.keyboard numlock-state 'on'

# disable automatic suspend
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
EOF
mkdir -p /usr/local/bin
chmod 755 /usr/local/bin/desktop-custom-configure

echo "==> activate DPMS"
cat <<- EOF > /etc/X11/xorg.conf
Section "ServerLayout"
 Identifier "Default Layout"
 Option "BlankTime" "0"
 Option "StandbyTime" "0"
 Option "SuspendTime" "0"
 Option "OffTime" "0"
EndSection
EOF

USERNAME=${SSH_USER}
LIGHTDM_CONFIG=/etc/lightdm/lightdm.conf
GDM_CUSTOM_CONFIG=/etc/gdm3/custom.conf

if [ -f $GDM_CUSTOM_CONFIG ]; then
    mkdir -p $(dirname ${GDM_CUSTOM_CONFIG})
    echo "" > $GDM_CUSTOM_CONFIG
    echo "[daemon]" >> $GDM_CUSTOM_CONFIG
    echo "# Enabling automatic login" >> $GDM_CUSTOM_CONFIG
    echo "AutomaticLoginEnable = true" >> $GDM_CUSTOM_CONFIG
    echo "AutomaticLogin = ${USERNAME}" >> $GDM_CUSTOM_CONFIG
fi

if [ -f $LIGHTDM_CONFIG ]; then
    echo "==> Configuring lightdm autologin"
    echo "[SeatDefaults]" >> $LIGHTDM_CONFIG
    echo "autologin-user=${USERNAME}" >> $LIGHTDM_CONFIG
    echo "autologin-user-timeout=0" >> $LIGHTDM_CONFIG
fi

if [ -d /etc/xdg/autostart/ ]; then
    echo "==> Custom xdg config (no screen blank, ...)"

    NODPMS_CONFIG=/etc/xdg/autostart/customXdgConfig.desktop
    echo "[Desktop Entry]" >> $NODPMS_CONFIG
    echo "Type=Application" >> $NODPMS_CONFIG
    echo "Exec=/usr/local/bin/desktop-custom-configure" >> $NODPMS_CONFIG
    echo "Hidden=false" >> $NODPMS_CONFIG
    echo "NoDisplay=false" >> $NODPMS_CONFIG
    echo "X-GNOME-Autostart-enabled=true" >> $NODPMS_CONFIG
    echo "Name[en_US]=custom xdg configuration" >> $NODPMS_CONFIG
    echo "Name=nodpms" >> $NODPMS_CONFIG
    echo "Comment[en_US]=" >> $NODPMS_CONFIG
    echo "Comment=" >> $NODPMS_CONFIG
fi

if [[ -d /etc/polkit-1/localauthority/ ]]; then
echo "[Re-enable hibernate by default in upower]
Identity=unix-user:*
Action=org.freedesktop.upower.hibernate
ResultActive=yes

[Re-enable hibernate by default in logind]
Identity=unix-user:*
Action=org.freedesktop.login1.hibernate;org.freedesktop.login1.handle-hibernate-key;org.freedesktop.login1;org.freedesktop.login1.hibernate-multiple-sessions;org.freedesktop.login1.hibernate-ignore-inhibit
ResultActive=yes" > /etc/polkit-1/localauthority/10-vendor.d/com.ubuntu.desktop.pkla
fi
