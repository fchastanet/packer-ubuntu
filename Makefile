# delete default suffixes
.SUFFIXES:
.EXPORT_ALL_VARIABLES:
.DEFAULT_GOAL   := help
THIS_MAKEFILE   :=$(MAKEFILE_LIST)

SHELL           := /bin/bash
SHELL_COMMAND   := bash

THIS_DIR 			  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
PACKER_FILES          := $(shell find $(THIS_DIR) -maxdepth 1 -type f -name "*.json")
SCRIPTS_SERVER_FILES  := $(shell find "$(THIS_DIR)/scripts" -type f)
SCRIPTS_DESKTOP_FILES := $(shell find "$(THIS_DIR)/scripts-desktop" -type f)

# you can override these variables by launching make like this
# $ make BOX_VERSION=1.0.0 HEADLESS=false USER="fchastanet" BOX="fchastanet-ubuntu-bionic64" CLOUD_TOKEN="verysecrettoken" build
# use this one if your vagrant cloud token is specifed in the file vagrant.token
# $ make BOX_VERSION=1.0.0 HEADLESS=false USER="fchastanet" BOX="fchastanet-ubuntu-bionic64" build
BOX_VERSION     ?= 1.0.5
HEADLESS        ?= true
CLOUD_TOKEN     ?= $(shell [[ -f vagrant.token ]] && cat vagrant.token || echo "no key provided")
PROVIDER        ?= virtualbox
USER            ?= fchastanet
BOX			    ?= fchastanet-ubuntu-bionic64
DESKTOP		    ?= gnome
VM_NAME         ?= fchastanet-dev-env
BOX_FILE_PREFIX := output-virtualbox-03

# UBUNTU iso information
UBUNTU_VERSION      := ubuntu-18.04
BASE_UBUNTU_ISO_URL := http://cdimage.ubuntu.com/ubuntu/releases/bionic/release/
UBUNTU_ISO_NAME     := ubuntu-18.04.3-server-amd64.iso
UBUNTU_ISO_URL      := $(BASE_UBUNTU_ISO_URL)/$(UBUNTU_ISO_NAME)
UBUNTU_ISO_CHECKSUM := 7d8e0055d663bffa27c1718685085626cb59346e7626ba3d3f476322271f573e

# dependencies versions
DOCKER_COMPOSE_VERSION := 1.24.1

.PHONY: help
help: ## Prints this help
help:
	@grep -E '(^[0-9a-zA-Z_-]+:.*?##.*$$)|(^##)' $(THIS_MAKEFILE) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

#-----------------------------------------------------------------------------
# BUILD DEPENDENCIES

$(HOME)/.ssh/id_rsa:
	@$(error "File '$@' does not exist! Exiting...")

$(HOME)/.ssh/pub.key:
	@$(error "File '$@' does not exist! Exiting...")

.PHONY: check_ssh_files
check_ssh_files: $(HOME)/.ssh/id_rsa $(HOME)/.ssh/pub.key

.PHONY: check_dependencies_packer_mandatory
check_dependencies_packer_mandatory: scripts-vagrant/makefile-check-dependencies.sh
	@$(SHELL_COMMAND) scripts-vagrant/makefile-check-dependencies.sh "packer-mandatory"

.PHONY: check_dependencies
check_dependencies: check_ssh_files scripts-vagrant/makefile-check-dependencies.sh
	@$(SHELL_COMMAND) scripts-vagrant/makefile-check-dependencies.sh

#-----------------------------------------------------------------------------
# Build

output-virtualbox-01/$(UBUNTU_VERSION)-base.ovf: 01-ubuntu-base.json http/preseed.cfg
	rm -Rf ./output-virtualbox-* "logs/01-baseImagePacker.log"
	./scripts-vagrant/makefile-pack-box.sh "$<" base "logs/01-baseImagePacker.log"

output-virtualbox-02/$(UBUNTU_VERSION)-server.ovf: 02-ubuntu-server.json output-virtualbox-01/$(UBUNTU_VERSION)-base.ovf $(SCRIPTS_SERVER_FILES)
	rm -Rf ./output-virtualbox-0{2,3}* "logs/02-serverImagePacker.log"
	./scripts-vagrant/makefile-pack-box.sh "$<" server "logs/02-serverImagePacker.log"

DESKTOP_COMMON_DEPENDENCIES = 03-ubuntu-desktop.json output-virtualbox-02/$(UBUNTU_VERSION)-server.ovf Vagrantfile.box.template $(SCRIPTS_DESKTOP_FILES)

output-virtualbox-03-gnome/$(UBUNTU_VERSION)-desktop.ovf: $(DESKTOP_COMMON_DEPENDENCIES)
	rm -Rf ./output-virtualbox-03-gnome "logs/03-desktopImagePacker-gnome.log"
	./scripts-vagrant/makefile-pack-box.sh "$<" gnome "logs/03-desktopImagePacker-gnome.log"

output-virtualbox-03-lxde/$(UBUNTU_VERSION)-desktop.ovf: $(DESKTOP_COMMON_DEPENDENCIES)
	rm -Rf ./output-virtualbox-03-lxde "logs/03-desktopImagePacker-lxde.log"
	./scripts-vagrant/makefile-pack-box.sh "$<" lxde "logs/03-desktopImagePacker-lxde.log"

output-virtualbox-03-serverX11/$(UBUNTU_VERSION)-desktop.ovf: $(DESKTOP_COMMON_DEPENDENCIES)
	rm -Rf ./output-virtualbox-03-serverX11 "logs/03-desktopImagePacker-serverX11.log"
	./scripts-vagrant/makefile-pack-box.sh "$<" serverX11 "logs/03-desktopImagePacker-serverX11.log"

IMAGE_BUILD_DEPS :=
IMAGE_BUILD_DEPS += output-virtualbox-01/$(UBUNTU_VERSION)-base.ovf
IMAGE_BUILD_DEPS += output-virtualbox-02/$(UBUNTU_VERSION)-server.ovf
IMAGE_BUILD_DEPS += $(BOX_FILE_PREFIX)-serverX11/$(UBUNTU_VERSION)-desktop.ovf
IMAGE_BUILD_DEPS += $(BOX_FILE_PREFIX)-lxde/$(UBUNTU_VERSION)-desktop.ovf
IMAGE_BUILD_DEPS += $(BOX_FILE_PREFIX)-gnome/$(UBUNTU_VERSION)-desktop.ovf
BOX_CREATED :=
BOX_CREATED += logs/box-base-created
BOX_CREATED += logs/box-server-created
BOX_CREATED += logs/box-serverX11-created
BOX_CREATED += logs/box-lxde-created
BOX_CREATED += logs/box-gnome-created

.PHONY: build
build: ## build images
build: check_dependencies_packer_mandatory $(IMAGE_BUILD_DEPS)
	@tail -n 1 $(BOX_CREATED)
	$(info build files are up to date)

#-----------------------------------------------------------------------------
# DEPLOY

.PHONY: deploy-box
deploy-box: $(BOX_FILE_PREFIX)-$(BOX_PACKED)/$(UBUNTU_VERSION)-desktop.box ImageDescription.md ImageDescription-$(BOX_PACKED).md
deploy-box: $(BOX_FILE_PREFIX)-$(BOX_PACKED)/deployed
	@$(SHELL_COMMAND) scripts-vagrant/makefile-vagrant-deploy.sh \
		"$(USER)" "$(BOX)-$(BOX_PACKED)" "$(BOX_VERSION)" "ImageDescription.md" "ImageDescription-$(BOX_PACKED).md" \
		"$(CLOUD_TOKEN)" "$(BOX_FILE_PREFIX)-$(BOX_PACKED)" "$(UBUNTU_VERSION)-desktop.box" "$(BOX_PACKED)"

$(BOX_FILE_PREFIX)-gnome/deployed: BOX_PACKED=gnome
$(BOX_FILE_PREFIX)-gnome/deployed: deploy-box

$(BOX_FILE_PREFIX)-lxde/deployed: BOX_PACKED=lxde
$(BOX_FILE_PREFIX)-lxde/deployed: deploy-box

$(BOX_FILE_PREFIX)-serverX11/deployed: BOX_PACKED=serverX11
$(BOX_FILE_PREFIX)-serverX11/deployed: deploy-box

.PHONY: deploy
deploy: ## build images and try to deploy it if vagrant token is provided
deploy: build $(BOX_FILE_PREFIX)-gnome/deployed $(BOX_FILE_PREFIX)-lxde/deployed $(BOX_FILE_PREFIX)-serverX11/deployed

#-----------------------------------------------------------------------------
# START

.PHONY: start
start: ## start the project using Vagrantfile (means you've first called make first-start or first-start-local before)
start:
	@-if [[ ! -f Vagrantfile ]]; then echo "before you should run 'make first-start' or 'make first-start-local'"; exit 1; fi
	vagrant up

.PHONY: first-start
first-start: ## start the project by downloading the box from vagrant cloud
first-start: ##       use `DESKTOP=lxde make first-start` to target lxde vm instead of gnome
first-start: check_dependencies Vagrantfile
	vagrant up

Vagrantfile: Vagrantfile.template
	[[ -f Vagrantfile ]] && (cp -v Vagrantfile Vagrantfile.bak && echo "Upgraded Vagrantfile - backup created") || true
	cp Vagrantfile.template Vagrantfile
	sed -i -e "s/@@@VM_NAME@@@/$(VM_NAME)-$(DESKTOP)/g" Vagrantfile || true
	sed -i -e "s#@@@VAGRANT_BOX@@@#$(USER)/$(BOX)-$(DESKTOP)#g" Vagrantfile || true
	sed -i -e "s#@@@VAGRANT_BOX_VERSION@@@#$(BOX_VERSION)#g" Vagrantfile || true

.PHONY: first-start-local
START_LOCAL_DEPS := output-virtualbox-01/$(UBUNTU_VERSION)-base.ovf
START_LOCAL_DEPS += output-virtualbox-02/$(UBUNTU_VERSION)-server.ovf
START_LOCAL_DEPS += $(BOX_FILE_PREFIX)-$(DESKTOP)/$(UBUNTU_VERSION)-desktop.ovf
first-start-local: ## start the project by using the box generated locally by packer
first-start-local: ##       use `DESKTOP=lxde make first-start-local` to target lxde vm instead of gnome
first-start-local: check_dependencies_packer_mandatory $(START_LOCAL_DEPS) Vagrantfile
	# remove all the versioned boxes
	vagrant box remove $(USER)/$(BOX)-$(DESKTOP) --all || true
	# add the local box to registry
	vagrant box add --force --name $(USER)/$(BOX)-$(DESKTOP) "$(BOX_FILE_PREFIX)-$(DESKTOP)/$(UBUNTU_VERSION)-desktop.box"
	# remove version from Vagrant file
	sed -i -e '/^[ \t]*virtualbox.vm.box_version = .*/d' Vagrantfile
	# up vagrant
	vagrant up

#-----------------------------------------------------------------------------
# TESTS

vendor:
	@mkdir -p vendor

vendor/bats-install:
	git clone https://github.com/sstephenson/bats.git vendor/bats-install

vendor/bats/bin/bats: vendor vendor/bats-install
	cd vendor/bats-install && ./install.sh "$(shell cd vendor && pwd)/bats"

test-box-gnome:
	@-if [[ ! -d output-virtualbox-03-gnome ]]; then echo "vm gnome tests skipped as vm image not built" exit 0; fi
	scripts-vagrant/makefile-test-box.sh "gnome" "00-Vagrantfile.template" "00-box-tests.bats"
	scripts-vagrant/makefile-test-box.sh "gnome" "01-Vagrantfile.template" "01-box-tests.bats"

test-box-serverx11:
	@-if [[ ! -d output-virtualbox-03-serverX11 ]]; then echo "vm serverX11 tests skipped as vm image not built" exit 0; fi
	scripts-vagrant/makefile-test-box.sh "serverX11" "00-Vagrantfile.template" "00-box-tests.bats"
	scripts-vagrant/makefile-test-box.sh "serverX11" "01-Vagrantfile.template" "01-box-tests.bats"

test-box-lxde:
	@-if [[ ! -d output-virtualbox-03-lxde ]]; then echo "vm lxde tests skipped as vm image not built" exit 0; fi
	scripts-vagrant/makefile-test-box.sh "lxde" "00-Vagrantfile.template" "00-box-tests.bats"
	scripts-vagrant/makefile-test-box.sh "lxde" "01-Vagrantfile.template" "01-box-tests.bats"

tests/01-Vagrantfile:
	@cp Vagrantfile.template tests/01-Vagrantfile.template
	@sed -i \
		-e "s/disk_variant = 'FIXED'/disk_variant = 'Standard'/g" \
		-e "s#disk_filename =.*#disk_filename = './test_userData.vdi'#g" \
		-e "/VAGRANT_BOX_VERSION = .*/d" \
		-e "s/VM_NAME = .*/VM_NAME = \"vm-test-@@@BOX_TESTED@@@-$(shell cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)\"/g" \
		-e "/virtualbox.vm.box_version.*/d" \
		-e '/config.vm.network "forwarded_port".*/d' \
		-e 's#File.dirname(__FILE__) + "#"..#g' \
		-e 's/v.gui = true/v.gui = false/g' \
		tests/01-Vagrantfile.template

.PHONY: tests
tests: vendor/bats/bin/bats tests/01-Vagrantfile
tests: test-box-gnome test-box-serverx11 test-box-lxde

#-----------------------------------------------------------------------------
# CLEAN

.PHONY: clean
clean: ## clean build files
clean:
	@$(info clean build files)
	rm -f logs/*
	rm -Rf output-virtualbox-*

.PHONY: clean-hard
clean-hard: ## clean artifacts, cache, build files
clean-hard: clean
	vagrant destroy
	rm -f iso/*
	rm -f packer_cache/*
	rm -Rf .vagrant
	rm -f Vagrantfile Vagrantfile.box
	rm -f vagrant.token
