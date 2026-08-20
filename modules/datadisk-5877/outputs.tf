output "disk_names" {
  description = "Names of the managed data disks."
  value       = { for k, d in azurerm_managed_disk.data : k => d.name }
}
