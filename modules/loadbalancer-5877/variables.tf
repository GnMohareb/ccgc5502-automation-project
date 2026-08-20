variable "prefix" { type = string }
variable "location" { type = string }
variable "rg_name" { type = string }
variable "tags" { type = map(string) }

variable "backend_nic_ids" {
  description = "Map of logical VM name to NIC ID. Every NIC is placed in the backend pool."
  type        = map(string)
}

variable "public_ip_sku" { type = string }

variable "name_suffix" { type = string }
