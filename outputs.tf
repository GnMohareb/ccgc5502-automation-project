# ---------------------------------------------------------------------------
# Every value the assignment requires printed on a successful deployment.
# ---------------------------------------------------------------------------

output "resource_group_name" {
  description = "Resource group holding the deployment."
  value       = module.rgroup.rg_name
}

# --- Networking -------------------------------------------------------------
output "virtual_network_name" {
  description = "Virtual network name."
  value       = module.network.vnet_name
}

output "subnet_name" {
  description = "Subnet name."
  value       = module.network.subnet_name
}

# --- Common services --------------------------------------------------------
output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name."
  value       = module.common.law_name
}

output "recovery_services_vault_name" {
  description = "Recovery Services vault name."
  value       = module.common.rsv_name
}

output "storage_account_name" {
  description = "Shared storage account name."
  value       = module.common.storage_account_name
}

# --- Linux VMs --------------------------------------------------------------
output "linux_hostnames" {
  description = "Hostnames of the Linux VMs."
  value       = module.vmlinux.hostnames
}

output "linux_fqdns" {
  description = "FQDNs of the Linux VMs."
  value       = module.vmlinux.fqdns
}

output "linux_private_ip_addresses" {
  description = "Private IP addresses of the Linux VMs."
  value       = module.vmlinux.private_ip_addresses
}

output "linux_public_ip_addresses" {
  description = "Public IP addresses of the Linux VMs."
  value       = module.vmlinux.public_ip_addresses
}

# --- Windows VM -------------------------------------------------------------
output "windows_hostnames" {
  description = "Hostnames of the Windows VMs."
  value       = module.vmwindows.hostnames
}

output "windows_fqdns" {
  description = "FQDNs of the Windows VMs."
  value       = module.vmwindows.fqdns
}

output "windows_private_ip_addresses" {
  description = "Private IP addresses of the Windows VMs."
  value       = module.vmwindows.private_ip_addresses
}

output "windows_public_ip_addresses" {
  description = "Public IP addresses of the Windows VMs."
  value       = module.vmwindows.public_ip_addresses
}

# --- Availability sets ------------------------------------------------------
output "linux_availability_set_name" {
  description = "Availability set containing the Linux VMs."
  value       = module.vmlinux.availability_set_name
}

output "windows_availability_set_name" {
  description = "Availability set containing the Windows VM."
  value       = module.vmwindows.availability_set_name
}

# --- Data disks -------------------------------------------------------------
output "data_disk_names" {
  description = "Managed data disks attached to the VMs."
  value       = module.datadisk.disk_names
}

# --- Load balancer ----------------------------------------------------------
output "load_balancer_name" {
  description = "Load balancer name."
  value       = module.loadbalancer.lb_name
}

output "load_balancer_public_ip" {
  description = "Public IP of the load balancer frontend."
  value       = module.loadbalancer.lb_public_ip
}

# --- Database ---------------------------------------------------------------
output "database_name" {
  description = "PostgreSQL server instance name."
  value       = module.database.db_name
}

output "database_fqdn" {
  description = "PostgreSQL server FQDN."
  value       = module.database.db_fqdn
}
