#!/usr/bin/env bats

ROOT_DIR="$( cd "${BATS_TEST_DIRNAME}/.." && pwd )"

# load bash-framework bootstrap
# shellcheck source=../vendor/bash-framework/bash-framework/_bootstrap.sh
source "${ROOT_DIR}/vendor/bash-framework/bash-framework/_bootstrap.sh"

import bash-framework/Version

BASE_USER=vagrant
OS_TYPE="Ubuntu"
OS_VERSION="18.04"
EXPECTED_BOX_VERSION="1.0.4"
MINIMAL_DOCKER_VERSION="19.03"
MINIMAL_DOCKER_COMPOSE_VERSION="1.24"
MINIMAL_NODE_VERSION="13.0.1"
MINIMAL_NPM_VERSION="6.12.0"

execute_vagrant_ssh_command() {
    vagrant ssh -c "${*}" -- -n -T
}

@test "We can start the VM with vagrant" {
    vagrant up
}

@test "We can SSH inside the VM with vagrant" {
    execute_vagrant_ssh_command "echo OK"
}

@test "Default user of the VM is ${BASE_USER}" {
    execute_vagrant_ssh_command "whoami" | grep "${BASE_USER}"
}

@test "Default shell of default user ${BASE_USER} is bash" {
    # Configured User shell
    execute_vagrant_ssh_command 'echo ${SHELL}' | grep '/bin/bash'
    # Effective shell
    execute_vagrant_ssh_command 'echo ${0}' | grep 'bash'
}

@test "We have the passwordless sudoers rights inside the VM" {
    execute_vagrant_ssh_command 'sudo whoami' | grep root
}

@test "Remote VM runs on ${OS_TYPE}, version ${OS_VERSION}" {
    execute_vagrant_ssh_command "grep NAME /etc/os-release | grep ${OS_TYPE} \
    && grep VERSION= /etc/os-release | grep ${OS_VERSION}"
}

@test "check box version" {
    boxVersion=$(execute_vagrant_ssh_command "cat /etc/motd | grep 'Box version '  | sed -E 's/^Box version (.*)$/\1/p' | tail -1")
    [[ "${boxVersion}" = "${EXPECTED_BOX_VERSION}" ]]
}

@test "SSH does not allow root login" {
    [[ "$(execute_vagrant_ssh_command \
        'grep PermitRootLogin /etc/ssh/sshd_config' \
        | grep yes | wc -l )" -eq 0 ]]
}

@test "SSH does not use DNS resolution (faster vagrant ssh)" {
    execute_vagrant_ssh_command "grep 'UseDNS no' /etc/ssh/sshd_config"
}

@test "The root filesystem is located on a LVM volume" {
     execute_vagrant_ssh_command 'sudo df -h | grep "/dev/vg0/lv_root" \
        | grep "/$" | wc -l'
}

@test "Swap is enabled" {
    [ $(execute_vagrant_ssh_command "free -m | grep Swap | awk '{print \$2}'") -ge 0 ]
}

@test "Docker Client is in the PATH" {
    execute_vagrant_ssh_command "which docker"
}

@test "Docker minimal version" {
  version=$(execute_vagrant_ssh_command "docker -v | sed -rn 's/Docker version ([^,]+),.*/\1/p'")
  run Version::compare ${version} ${MINIMAL_DOCKER_VERSION}
  [[ ${status} -ge 0 ]]
}

@test "Docker Compose is in the PATH and executable" {
  execute_vagrant_ssh_command "which docker-compose"
}

@test "Docker Compose minimal version" {
  version=$(execute_vagrant_ssh_command "docker-compose -v | sed -rn 's/docker-compose version ([^,]+),.*/\1/p'")
  run Version::compare ${version} ${MINIMAL_DOCKER_COMPOSE_VERSION}
  [[ ${status} -ge 0 ]]
}

@test "node is in the PATH and executable" {
  execute_vagrant_ssh_command "which node"
}

@test "Node minimal version" {
  version=$(execute_vagrant_ssh_command "node -v")
  run Version::compare "${version:1}" "${MINIMAL_NODE_VERSION}"
  [[ ${status} -ge 0 ]]
}

@test "npm is in the PATH and executable" {
  execute_vagrant_ssh_command "which npm"
}

@test "Npm minimal version" {
  version=$(execute_vagrant_ssh_command "npm -v")
  run Version::compare "${version}" "${MINIMAL_NPM_VERSION}"
  [[ ${status} -ge 0 ]]
}

@test "stylelint is in the PATH" {
    execute_vagrant_ssh_command "which stylelint"
}

@test "prettier is in the PATH" {
    execute_vagrant_ssh_command "which prettier"
}

@test "sass-lint is in the PATH" {
    execute_vagrant_ssh_command "which sass-lint"
}

@test "shellcheck is in the PATH" {
    execute_vagrant_ssh_command "which shellcheck"
}

@test "shellcheck is in the PATH" {
    execute_vagrant_ssh_command "which shellcheck"
}

@test "php is in the PATH" {
    execute_vagrant_ssh_command "which php"
}

@test "phpcs is in the PATH" {
    execute_vagrant_ssh_command "which phpcs"
}

@test "phpcbf is in the PATH" {
    execute_vagrant_ssh_command "which phpcbf"
}

@test "phpmd is in the PATH" {
    execute_vagrant_ssh_command "which phpmd"
}

@test "The default admin user ${BASE_USER} is in the docker group" {
  execute_vagrant_ssh_command "grep docker /etc/group | grep ${BASE_USER}"
}

@test "Docker Engine is started and respond correctly without sudo" {
  execute_vagrant_ssh_command "docker info"
}

@test "jetbrains toolbox is in the PATH" {
    execute_vagrant_ssh_command "which jetbrains-toolbox"
}

@test "Java command can be run inside container (no Kernel enforcing blocking syscalls)" {
  execute_vagrant_ssh_command "docker run --rm -t maven:3-alpine java -version"
}

@test "We have a shutdown command" {
    execute_vagrant_ssh_command "which shutdown" | grep '/sbin/shutdown'
}
