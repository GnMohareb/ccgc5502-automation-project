variable "prefix" { type = string }
variable "location" { type = string }
variable "rg_name" { type = string }
variable "tags" { type = map(string) }
variable "subnet_id" { type = string }
variable "vm_size" { type = string }
variable "vm_count" { type = number }
variable "admin_username" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "boot_diagnostics_uri" { type = string }

variable "public_ip_sku" { type = string }

variable "name_suffix" { type = string }
