#!/usr/bin/env bash

echo "install docker"
apt-get update -y --fix-missing
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add
apt-key fingerprint 0EBFCD88
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update -y --fix-missing
DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends docker-ce
groupadd docker
usermod -aG docker ${SSH_USERNAME}

echo "change docker files location"
service docker stop
mkdir /home/vagrant/docker-files
mv /var/lib/docker/* /home/vagrant/docker-files
rm -Rf /var/lib/docker
ln -s /home/vagrant/docker-files /var/lib/docker
service docker start

echo "installing docker-compose ${DOCKER_COMPOSE_VERSION}"
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

