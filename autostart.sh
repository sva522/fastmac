#!/bin/bash
exit 0
cd $(dirname $0)

# Update distro
sudo apt update
sudo apt -y upgrade

## Update to last version (no lts) # Too long => disabled
## Enable normal release
# sudo sed -i 's/Prompt=lts/Prompt=normal/g' /etc/update-manager/release-upgrades
## Remove blocked packages
# sudo apt remove mysql*
# Do update...
# do-release-upgrade -f DistUpgradeViewNonInteractive

# Install base packages
sudo apt install -y ansible
ansible-playbook playbook.yaml

# Always start vm
exit 0
