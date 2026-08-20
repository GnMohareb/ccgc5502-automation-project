variable "prefix" { type = string }
variable "location" { type = string }
variable "rg_name" { type = string }
variable "tags" { type = map(string) }
variable "disk_size_gb" { type = number }

variable "vm_ids" {
  description = "Map of logical VM name to VM resource ID. One disk is created and attached per entry."
  type        = map(string)
}
