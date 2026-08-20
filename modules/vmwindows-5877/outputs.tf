output "hostnames" {
  description = "Computer name of each Windows VM."
  value       = [for vm in azurerm_windows_virtual_machine.win_vm : vm.computer_name]
}

output "fqdns" {
  description = "Fully qualified domain name of each Windows VM."
  value       = [for pip in azurerm_public_ip.win_pip : pip.fqdn]
}

output "private_ip_addresses" {
  description = "Private IP address of each Windows VM."
  value       = [for nic in azurerm_network_interface.win_nic : nic.private_ip_address]
}

output "public_ip_addresses" {
  description = "Public IP address of each Windows VM."
  value       = [for pip in azurerm_public_ip.win_pip : pip.ip_address]
}

output "vm_ids" {
  description = "Resource IDs of the Windows VMs, consumed by the data disk module."
  value       = [for vm in azurerm_windows_virtual_machine.win_vm : vm.id]
}

output "availability_set_name" {
  description = "Name of the Windows availability set."
  value       = azurerm_availability_set.win_avset.name
}
