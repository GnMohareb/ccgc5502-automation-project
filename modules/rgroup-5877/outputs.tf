output "rg_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.rg.name
}

output "rg_location" {
  description = "Region the resource group was created in."
  value       = azurerm_resource_group.rg.location
}
