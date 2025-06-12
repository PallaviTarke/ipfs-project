#!/bin/bash

# Install dependencies
sudo apt update
sudo apt install -y wget

# Install IPFS (Kubo)
wget https://dist.ipfs.tech/kubo/v0.28.0/kubo_v0.28.0_linux-amd64.tar.gz
tar -xvzf kubo_v0.28.0_linux-amd64.tar.gz
cd kubo
sudo bash install.sh
ipfs init

# Isolate from public IPFS network
ipfs bootstrap rm --all
ipfs config Routing.Type none

# Start IPFS daemon in the background
ipfs daemon &