#!/bin/bash

exit 0
cd $HOME
rm -rf $HOME/*

echo neofetch >> ~/.bashrc

if [ $(id -u) -ne 0 ]; then
    sudo $0
    exit 0
fi

sudo apt-get update -y
sudo apt-get install -y make gcc neofetch fish

# Always start vm
exit 0
