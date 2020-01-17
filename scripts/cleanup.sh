#!/bin/sh
set -x

# Clean up
echo "==> Clean up"
DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge
DEBIAN_FRONTEND=noninteractive apt-get -y clean

# Remove temporary files
rm -rf /tmp/*

# writes zeroes to all empty space on the volume; this allows for better compression of the physical file containing the virtual disk.
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY

# reboot
echo "====> Shutting down the SSHD service and rebooting..."
systemctl stop sshd.service
nohup shutdown -r now < /dev/null > /dev/null 2>&1 &
sleep 120
exit 0