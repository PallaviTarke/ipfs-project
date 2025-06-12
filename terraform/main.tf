# Configure the Azure provider
provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
}

# Resource Group
resource "azurerm_resource_group" "ipfs_rg" {
  name     = "ipfs-resource-group"
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "ipfs_vnet" {
  name                = "ipfs-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.ipfs_rg.location
  resource_group_name = azurerm_resource_group.ipfs_rg.name
}

# Public Subnet for Azure Bastion
resource "azurerm_subnet" "public_subnet" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.ipfs_rg.name
  virtual_network_name = azurerm_virtual_network.ipfs_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Private Subnet for IPFS Nodes
resource "azurerm_subnet" "private_subnet" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.ipfs_rg.name
  virtual_network_name = azurerm_virtual_network.ipfs_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Azure Bastion Subnet (must be named AzureBastionSubnet)
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.ipfs_rg.name
  virtual_network_name = azurerm_virtual_network.ipfs_vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Public IP for Azure Bastion
resource "azurerm_public_ip" "bastion_pip" {
  name                = "bastion-pip"
  location            = azurerm_resource_group.ipfs_rg.location
  resource_group_name = azurerm_resource_group.ipfs_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Azure Bastion Host
resource "azurerm_bastion_host" "bastion" {
  name                = "ipfs-bastion"
  location            = azurerm_resource_group.ipfs_rg.location
  resource_group_name = azurerm_resource_group.ipfs_rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}

# Network Security Group for Private Nodes
resource "azurerm_network_security_group" "private_nsg" {
  name                = "private-nsg"
  location            = azurerm_resource_group.ipfs_rg.location
  resource_group_name = azurerm_resource_group.ipfs_rg.name

  # SSH from Bastion (Azure Bastion uses internal routing, so no explicit rule needed)
  security_rule {
    name                       = "allow-app-3000"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ipfs-api-5001"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5001"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ipfs-swarm-4001"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4001"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-smb-445"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "445"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
}

# Associate NSG with Private Subnet
resource "azurerm_subnet_network_security_group_association" "private_nsg_assoc" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.private_nsg.id
}

# SSH Key for VMs
resource "tls_private_key" "ipfs_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Storage Account for Azure Files
resource "azurerm_storage_account" "ipfs_storage" {
  name                     = "ipfsstorageacct"
  resource_group_name      = azurerm_resource_group.ipfs_rg.name
  location                 = azurerm_resource_group.ipfs_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Azure File Share
resource "azurerm_storage_share" "ipfs_share" {
  name                 = "ipfs-share"
  storage_account_name = azurerm_storage_account.ipfs_storage.name
  quota                = 50
}

# Private Nodes (IPFS + Node.js)
resource "azurerm_network_interface" "private_nic" {
  count               = 5
  name                = "private-nic-${count.index + 1}"
  location            = azurerm_resource_group.ipfs_rg.location
  resource_group_name = azurerm_resource_group.ipfs_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "private_nodes" {
  count               = 5
  name                = "private-node-${count.index + 1}"
  resource_group_name = azurerm_resource_group.ipfs_rg.name
  location            = azurerm_resource_group.ipfs_rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "ubuntu"
  network_interface_ids = [
    azurerm_network_interface.private_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = "Ubuntu"
    public_key = tls_private_key.ipfs_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Name = "private-node-${count.index + 1}"
  }
}