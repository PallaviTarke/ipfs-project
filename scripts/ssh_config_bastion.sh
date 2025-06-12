#!/bin/bash

# Read Terraform outputs
BASTION_IP=$(jq -r '.bastion_pip.value' outputs.json)
PRIVATE_IPS=$(jq -r '.private_ips.value[]' outputs.json)

# Generate SSH config
cat > ssh_config <<EOL
Host bastion
    HostName $BASTION_IP
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no

Host private-*
    User ubuntu
    ProxyJump bastion
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
EOL

# Configure hosts for private IPs
i=1
for ip in $PRIVATE_IPS; do
    echo "Host private-$i" >> ssh_config
    echo "    HostName $ip" >> ssh_config
    i=$((i + 1))
done

# Extract storage account key for Azure Files
STORAGE_KEY=$(az storage account keys list --account-name ipfsstorageacct --query "[0].value" -o tsv)
echo $STORAGE_KEY > /tmp/storage_key