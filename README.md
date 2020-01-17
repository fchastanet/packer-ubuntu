# Packer - Ubuntu 18.04 minimal Vagrant Box

**Current Ubuntu Version Used**: 18.04.1

This build configuration installs and configures Ubuntu 18.04 x86_64 server with softwares
like docker, git, and then generates a Vagrant box file for VirtualBox.

## Requirements

The following software must be installed/present on your local machine before you can use Packer to build the Vagrant box file:

  - [Packer](http://www.packer.io/)
  - [Vagrant](http://vagrantup.com/)
  - [VirtualBox](https://www.virtualbox.org/) (if you want to build the VirtualBox box)
  - HyperV (if you want to build hyperv Box)

for hyperV
    you will need to create an external virtual switch with the name ExternalVirtualSwitch
    also you will need to set a mac_address and add static bail on DHCP

the following vagrant plugins will be automatically installed during vagrant up
  - vagrant-vbguest
  - vagrant-timezone 
  - vagrant-persistent-storage

## Softwares installed
check [ImageDescription.md] file

## Build Usage

Make sure all the required softwares (listed above) are installed, then cd to the directory containing this README.md file, and run:

    make BOX_VERSION=1.0.0 HEADLESS=false USER="fchastanet" BOX="fchastanet-bionic64" build

After about 40 minutes, Packer should tell you the box was generated successfully.

> **Note**: in order to deploy to vagrant cloud, you must provide your token in the file `vagrant.token`

then you can deploy using 
    
    make BOX_VERSION=1.0.0 HEADLESS=false USER="fchastanet" BOX="fchastanet-bionic64" deploy
    
you can see build logs in logs directory

## launch your built images

box with gnome desktop manager (default) 
    
    make start-local
    
box with lxde desktop manager
    
    DESKTOP="lxde" make start-local

## storage disk
a storage disk is automatically created in your user folder
when vagrant image is started

## Resize your storage disk
you run out of disk space, here 2 recipes

**First shutdown your VM**

### Resize fixed size vdi file 

I suggest you to pass to dynamic file instead as performance gain is not so high with fixed size vdi file 

#### Step 1 : resize the volume

From git bash launch these commands **Note: first change VDI_FILE variable and size variable !!!**

    # change the name of the your vdi file first 
    VDI_FILE="@yourfile@.vdi"
    # set it the new size (in MB) => here we set 100GB 
    NEW_SIZE=100000
    # go where your vdi file is stored
    cd $HOME
    # backup your vdi file (just in case)
    cp "${VDI_FILE}" "${VDI_FILE%%.*}_$(date +%F)_backup.vdi"
    # resize 
    VBoxManage modifyhd "${VDI_FILE}" --resize "${NEW_SIZE}"

#### Step 2 : use gparted live CD
[http://derekmolloy.ie/resize-a-virtualbox-disk/]

#### Step 3 : Resize linux partition
connect as root on the VM

    # stop services
    service docker stop
    service gdm stop
    # unmount /dev/sdb
    umount -l /home/vagrant
    # deactivate the logical volumes from vps group
    vgchange -d -an vps
    # resize the logical volume to 100% of the new size
    lvextend -l+100%FREE /dev/vps/vps
    # check the volume
    e2fsck -f /dev/vps/vps
    # reactivate the logical volumes from vps group
    vgchange -d -ay vps
    # extend the filesystem on the whole LV
    resize2fs /dev/vps/vps
    
### Migrate from fixed size to dynamic size

Dynamic is better on SSD disks, because there is never-ending resize of this file and virtualbox must allocate new space if the virtual machine grows in lifetime. 

#### Step 1 : migrate to Standard size

Go to where your .vdi file is stored

    OLD_VDI_FILE=<source>.vdi
    RESIZED_VDI_FILE=dest_dynamicSize.vdi
    # set it the new size (in MB) => here we set 100GB 
    NEW_SIZE=100000
    VBoxManage clonehd "${OLD_VDI_FILE}" "${RESIZED_VDI_FILE}" --variant Standard
    VBoxManage modifyhd "${RESIZED_VDI_FILE}" --resize "${NEW_SIZE}"

#### Step 2 : use gparted live CD
[http://derekmolloy.ie/resize-a-virtualbox-disk/]
     
#### Alternative : create a new volume

Idea is to create a new volume
mount old volume as secondary in your vm
boot the vm
you will have to copy all your data back to /home/vagrant 

#### documentation
https://www.howtogeek.com/howto/40702/how-to-manage-and-use-lvm-logical-volume-management-in-ubuntu/
https://www.tecmint.com/extend-and-reduce-lvms-in-linux/
https://www.monlinux.net/2014/12/reduire-augmenter-taille-logical-volume-lvm/

## Launching built boxes

There's an included Vagrantfile that allows quick testing of the built Vagrant boxes. 
From this same directory, run the following command after building the box:

box with gnome desktop manager (default) 
    
    make start
    
box with lxde desktop manager
    
    DESKTOP="lxde" make start
    
## FAQ

### duplicate directory containing vagrant files
delete the directory .vagrant to avoid to be linked to the old vms

### error C:/HashiCorp/Vagrant/embedded/mingw64/lib/ruby/2.4.0/resolv.rb:834:in `connect': The requested address is not valid in its context. - connect(2) for "0.0.0.0" port 53 (Errno::EADDRNOTAVAIL)
replace all occurrences of 0.0.0.0 by localhost in the file 
    `C:\HashiCorp\Vagrant\embedded\mingw64\lib\ruby\2.4.0\resolv.rb`

## TODO
it was useful to have intermediate image at the beginning in order to debug compilation of the vm image.
But now we can merge packer files into 1 file to reduce compilation time.

## License

MIT license.
