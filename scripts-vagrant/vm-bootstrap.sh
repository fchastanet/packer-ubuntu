#!/usr/bin/env bash
set -ex

[[ "$(id -u)" = "0" ]] || {
    echo "bootstrap need to be executed as root - halt the vm"
    sudo halt
    exit 1
}

err_report() {
    echo "Error on line $1 - VM has been halted"
    halt
    exit 1
}

trap 'err_report $LINENO' ERR

REBOOT=0

fixRights() {
    find /home/vagrant -maxdepth 1 -type d -name ".*" \
        -exec chmod 755 {} ';' \
        -exec chown vagrant:vagrant {} ';'
    find /home/vagrant -maxdepth 1 -type f -name ".*" \
        -exec chmod 640 {} ';' \
        -exec chown vagrant:vagrant {} ';'
}

# it could happen sometimes that sticky bit is lost on gosu executable
fixDockerGosu() {
    find /home/vagrant/docker-files -name gosu -exec chown root:root {} ';'  -exec chmod +s {} ';'
}

moveHome() {
  # sdb is in the vps group
  # deactivate the logical volumes from vps group
  vgchange -d -a n vps
  # add sdb1 to fstab
  bash -c "echo '/dev/mapper/vps-vps /home/vagrant ext4 defaults 0 2' >> /etc/fstab"
  bash -c 'date > /etc/provision_env_disk_added_date'

  # stop docker service during files copy
  service docker stop

  # first move /home/vagrant that will be copied to the new disk
  mv /home/vagrant /tmp

  # reactivate the logical volumes from vps group
  vgchange -d -a y vps
  mkdir -vp /home/vagrant
  mount /home/vagrant

  # copy back the initial vagrant user files to this disk
  if [[ -f /home/vagrant/.bashrc ]]; then
    echo "/home/vagrant is already initialized"
  else
    echo "initialize /home/vagrant ..."
    cp -r /tmp/vagrant/. /home/vagrant
    chown -R vagrant:vagrant /home/vagrant
  fi
  rm -R /tmp/vagrant

  fixRights
}

# if /dev/sdb1 is not in /etc/fstab then do the copy
if [[ -L /dev/mapper/vps-vps && "$(cat /etc/fstab  | grep /home/vagrant)" = "" ]]; then
  moveHome
  REBOOT=1
fi

# configure user settings at every startup
configure() {
    # configure vi/vim
    cp -r /home/vagrantConf/. /home/vagrant

    dirs=(
      /home/vagrant/.bin
    )

    for dir in "${dirs[@]}"; do
      echo "Fix rights of '${dir}'"
      chmod 755 "${dir}"
      chmod 755 "${dir}/*.sh" 2>/dev/null || true
    done
    chmod 755 /home/vagrant/.bin/*

    # Install ssh keys
    [[ -f /home/vagrant/.ssh/authorized_keys ]] && cp /home/vagrant/.ssh/authorized_keys /home/vagrant/.ssh/authorized_keys_vagrant
    echo "=> copy host .ssh files to vagrant home"
    mkdir -pm 700 /home/vagrant/.ssh
    cp /hostHome/.ssh/* /home/vagrant/.ssh
    find /home/vagrant/.ssh -type f -exec chmod 600 {} ';'
    chmod 644 /home/vagrant/.ssh/pub.key || true

    if [[ -f /home/vagrant/.ssh/authorized_keys_vagrant ]]; then
      cat /home/vagrant/.ssh/authorized_keys_vagrant >> /home/vagrant/.ssh/authorized_keys
      rm -f /home/vagrant/.ssh/authorized_keys_vagrant
    fi

    # update .bashrc with dynamic variables
    if [[ -n "${DNS_HOSTNAME}" ]]; then
      sed -i -E \
        -e "s/export DNS_HOSTNAME=\"[^\"]*\"/export DNS_HOSTNAME=\"${DNS_HOSTNAME}\"/" \
        /home/vagrant/.bashrc
    fi
    if [[ -n "${HOST_USERNAME}" ]]; then
      sed -i -E \
        -e "s/export HOST_USERNAME=\"[^\"]*\"/export HOST_USERNAME=\"${HOST_USERNAME}\"/" \
        /home/vagrant/.bashrc
    fi

    fixDockerGosu

    mkdir -p /home/vagrant/.packer.doNotDelete || true
    # create file to avoid setting this part next time
    echo $(date) > /home/vagrant/.packer.doNotDelete/v0
}
[[ ! -f /home/vagrant/.packer.doNotDelete/v0 || ! -f /home/vagrant/.gitignore ]] && configure

# configure user settings only when migrating from V0 to V1
configureV1() {
    # remove useless files
    rm -f /home/vagrant/VBoxGuestAdditions.iso || true

    # configure dns
    cp /home/vagrantConf/etc/netplan/50-vagrant.yaml /etc/netplan/50-vagrant.yaml
    netplan apply

    # configure docker in order to use subnet different than 172.22.*.* (so zarmi does not work)
    cp /home/vagrantConf/etc/docker/daemon.json /etc/docker/daemon.json
    service docker restart

    # create file to avoid setting this part next time
    echo $(date) > /home/vagrant/.packer.doNotDelete/v1
}
[[ ! -f /home/vagrant/.packer.doNotDelete/v1 ]] && configureV1

if [[ "${REBOOT}" = "1" ]]; then
    # we need to reboot in order to restart docker and to let linux take home changes into account
    # to avoid issue "shell-init error retrieving current directory"
    /sbin/shutdown -r now < /dev/null > /dev/null 2>&1
    exit 0
fi
