variable "prefix" { type = string }
variable "location" { type = string }
variable "rg_name" { type = string }
variable "tags" { type = map(string) }
variable "subnet_id" { type = string }
variable "vm_size" { type = string }
variable "vm_names" { type = set(string) }
variable "admin_username" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "boot_diagnostics_uri" { type = string }

variable "netwatcher_ext_version" {
  description = "Type handler version of the Network Watcher agent."
  type        = string
  default     = "1.4"
}

variable "monitor_ext_version" {
  description = "Type handler version of the Azure Monitor agent."
  type        = string
  default     = "1.0"
}

variable "public_ip_sku" { type = string }

variable "name_suffix" { type = string }

variable "ssh_public_key_path" { type = string }
variable "ssh_private_key_path" { type = string }
variable "ansible_dir" { type = string }
variable "ansible_playbook" { type = string }
