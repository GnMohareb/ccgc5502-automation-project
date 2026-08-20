output "hostnames" {
  description = "Computer name of each Linux VM."
  value       = { for k, vm in azurerm_linux_virtual_machine.linux_vm : k => vm.computer_name }
}

output "fqdns" {
  description = "Fully qualified domain name of each Linux VM."
  value       = { for k, pip in azurerm_public_ip.linux_pip : k => pip.fqdn }
}

output "private_ip_addresses" {
  description = "Private IP address of each Linux VM."
  value       = { for k, nic in azurerm_network_interface.linux_nic : k => nic.private_ip_address }
}

output "public_ip_addresses" {
  description = "Public IP address of each Linux VM."
  value       = { for k, pip in azurerm_public_ip.linux_pip : k => pip.ip_address }
}

output "vm_ids" {
  description = "Resource IDs of the Linux VMs, consumed by the data disk module."
  value       = { for k, vm in azurerm_linux_virtual_machine.linux_vm : k => vm.id }
}

output "nic_ids" {
  description = "NIC IDs of the Linux VMs, consumed by the load balancer module."
  value       = { for k, nic in azurerm_network_interface.linux_nic : k => nic.id }
}

output "availability_set_name" {
  description = "Name of the Linux availability set."
  value       = azurerm_availability_set.linux_avset.name
}
