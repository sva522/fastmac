#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y make gcc neofetch powerline
sudo curl https://getmic.ro | bash
sudo micro -plugin install gotham-colors

# Always start vm
exit 0
