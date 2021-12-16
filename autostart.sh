#!/bin/bash

# Update distro
sudo apt update
sudo apt -y upgrade

# Remove blocked packages
sudo apt remove mysql*

sudo sed -i 's/Prompt=lts/Prompt=normal/g' /etc/update-manager/release-upgrades

# Update to last version (no lts)
do-release-upgrade -f DistUpgradeViewNonInteractive

# Install base packages
sudo apt install -y cmake make gcc neofetch fish nmap micro

# Add settings
echo neofetch >> ~/.bashrc
sudo sed -i 's+/home/runner:/bin/bash+/home/runner:/usr/bin/fish+g' /etc/passwd
sudo cat nanorc > /etc/nanorc

# Always start vm
exit 0
