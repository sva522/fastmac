#!/bin/bash

cd $HOME
rm -rf $HOME/*

echo neofetch >> ~/.bashrc

if [ $(id -u) -ne 0 ]; then
    sudo $0
    exit 0
fi

sudo apt-get update -y >/dev/null
sudo apt-get install -y make gcc neofetch fish >/dev/null

# Install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-get remove moby*

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
 
#docker run --rm -ti centos

#curl -fsSL https://code-server.dev/install.sh | sh

# Always start vm
exit 0
