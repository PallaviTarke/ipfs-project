output "bastion_pip" {
  value = azurerm_public_ip.bastion_pip.ip_address
}

output "private_ips" {
  value = azurerm_network_interface.private_nic[*].private_ip_address
}

output "ssh_private_key" {
  value     = tls_private_key.ipfs_ssh.private_key_pem
  sensitive = true
}