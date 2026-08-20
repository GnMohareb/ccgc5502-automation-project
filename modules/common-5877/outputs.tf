output "law_name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.law.name
}

output "rsv_name" {
  description = "Name of the Recovery Services vault."
  value       = azurerm_recovery_services_vault.rsv.name
}

output "storage_account_name" {
  description = "Name of the shared storage account."
  value       = azurerm_storage_account.sa.name
}

output "boot_diagnostics_uri" {
  description = "Blob endpoint used by every VM for boot diagnostics."
  value       = azurerm_storage_account.sa.primary_blob_endpoint
}

output "backup_policy_name" {
  description = "Name of the VM backup policy held in the Recovery Services vault."
  value       = azurerm_backup_policy_vm.vm_backup.name
}
