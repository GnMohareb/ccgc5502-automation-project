variable "prefix" { type = string }
variable "location" { type = string }
variable "rg_name" { type = string }
variable "tags" { type = map(string) }
variable "vnet_address_space" { type = list(string) }
variable "subnet_address_prefixes" { type = list(string) }
variable "allowed_ports" { type = list(string) }
