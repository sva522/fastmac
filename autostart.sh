#!/bin/bash

# Update distro
sudo apt-get update
sudo apt-get -y upgrade
# Install base packages
sudo apt-get install -y cmake make gcc neofetch fish nmap micro

# Add settings
echo neofetch >> ~/.bashrc
sudo sed -i 's+/home/runner:/bin/bash+/home/runner:/usr/bin/fish+g' /etc/passwd
cat nanorc > /etc/nanorc

# Always start vm
exit 0
