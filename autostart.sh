#!/bin/bash

# Update distro
sudo apt update
sudo apt -y upgrade

## Update to last version (no lts)
### Too long => disabled
## Enable normal release
# sudo sed -i 's/Prompt=lts/Prompt=normal/g' /etc/update-manager/release-upgrades
## Remove blocked packages
# sudo apt remove mysql*
# Do update...
# do-release-upgrade -f DistUpgradeViewNonInteractive

# Install base packages
sudo apt install -y cmake make gcc neofetch fish nmap micro

# Add settings
echo neofetch >> ~/.bashrc
sudo sed -i 's+/home/runner:/bin/bash+/home/runner:/usr/bin/fish+g' /etc/passwd
sudo cp nanorc /etc/nanorc

# Always start vm
exit 0
