#!/usr/bin/env bash
set -x

# ensure that we have insecure key to avoid vagrant 'Warning: Authentication failure. Retrying...'
# vagrant will renew this key automatically the first time once sucessfully connected
mkdir -pm 700 /home/vagrant/.ssh
curl -L https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub -o /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# remove unwanted packages
DEBIAN_FRONTEND=noninteractive apt-get -y remove \
    ufw

# Disable the release upgrader
echo "==> Disabling the release upgrader"
sed -i -e 's/^Prompt=.*$/Prompt=never/' /etc/update-manager/release-upgrades
echo "==> Removing the release upgrader"
DEBIAN_FRONTEND=noninteractive apt-get -y purge ubuntu-release-upgrader-core
rm -rf /var/lib/ubuntu-release-upgrader
rm -rf /var/lib/update-manager

# Disable IPv6 and remove splash screen
ipV6Grub="quiet nosplash"
ipV6Enabled="1"

if [[ $DISABLE_IPV6 =~ true || $DISABLE_IPV6 =~ 1 || $DISABLE_IPV6 =~ yes ]]; then
    echo "==> Disabling IPv6"
    ipV6Grub="${ipV6Grub} ipv6.disable=1"
    ipV6Enabled="0"
fi
sed -i \
  -e "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"${ipV6Grub}\"/" \
  -e "s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"${ipV6Grub}\"/" \
  /etc/default/grub

# Remove grub timeout
sed -i -e '/^GRUB_TIMEOUT=/aGRUB_RECORDFAIL_TIMEOUT=0' /etc/default/grub

update-grub

if grep 'net.ipv6.conf.all.disable_ipv6' /etc/sysctl.conf; then
    sed -i \
      -e "s/net.ipv6.conf.all.disable_ipv6=.*/net.ipv6.conf.all.disable_ipv6=${ipV6Enabled}/" \
      -e "s/net.ipv6.conf.default.disable_ipv6=.*/net.ipv6.conf.default.disable_ipv6=${ipV6Enabled}/" \
      /etc/sysctl.conf
else
    echo "net.ipv6.conf.all.disable_ipv6=${ipV6Enabled}" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6=${ipV6Enabled}" >> /etc/sysctl.conf
fi
sysctl --system

# SSH tweaks
echo "UseDNS no" >> /etc/ssh/sshd_config
