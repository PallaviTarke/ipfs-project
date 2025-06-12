#!/bin/bash

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install app dependencies
cd ~/nodejs-app
npm install

# Mount Azure Files share (if not already mounted)
sudo mkdir -p /mnt/ipfs_share
sudo apt install -y cifs-utils
sudo mount -t cifs //ipfsstorageacct.file.core.windows.net/ipfs-share /mnt/ipfs_share -o vers=3.0,username=ipfsstorageacct,password=$(cat /tmp/storage_key),dir_mode=0777,file_mode=0777,serverino

# Create ipfs_cids.txt if it doesn't exist
sudo touch /mnt/ipfs_share/ipfs_cids.txt
sudo chmod 666 /mnt/ipfs_share/ipfs_cids.txt

# Start the Node.js app
npm start &