# ---------------------------------------------------------------------------
# Root module - assignment1-5877
# Every resource is provisioned through a child module.
# ---------------------------------------------------------------------------

locals {
  # Tags required by the assignment, applied to every resource via each module.
  common_tags = merge(var.tags, {
    Prefix    = var.prefix
    ManagedBy = "Terraform"
    Region    = var.location
  })

  # Data disks are attached to all four VMs - the three Linux plus the Windows.
  # Both module outputs are folded into one map keyed by logical VM name.
  all_vm_ids = merge(
    module.vmlinux.vm_ids,
    { for idx, id in module.vmwindows.vm_ids : "wvm${idx + 1}" => id }
  )
}

module "rgroup" {
  source = "./modules/rgroup-5877"

  prefix      = var.prefix
  location    = var.location
  tags        = local.common_tags
  name_suffix = var.name_suffix
}

module "network" {
  source = "./modules/network-5877"

  prefix                  = var.prefix
  location                = var.location
  rg_name                 = module.rgroup.rg_name
  tags                    = local.common_tags
  vnet_address_space      = var.vnet_address_space
  subnet_address_prefixes = var.subnet_address_prefixes
  allowed_ports           = var.allowed_ports
}

module "common" {
  source = "./modules/common-5877"

  prefix      = var.prefix
  location    = var.location
  rg_name     = module.rgroup.rg_name
  tags        = local.common_tags
  name_suffix = var.name_suffix
}

module "vmlinux" {
  source = "./modules/vmlinux-5877"

  prefix               = var.prefix
  location             = var.location
  rg_name              = module.rgroup.rg_name
  tags                 = local.common_tags
  subnet_id            = module.network.subnet_id
  vm_size              = var.vm_size
  vm_names             = var.linux_vm_names
  public_ip_sku        = var.public_ip_sku
  name_suffix          = var.name_suffix
  admin_username       = var.admin_username
  admin_password       = var.admin_password
  boot_diagnostics_uri = module.common.boot_diagnostics_uri
  ssh_public_key_path  = var.ssh_public_key_path
  ssh_private_key_path = var.ssh_private_key_path
  ansible_dir          = var.ansible_dir
  ansible_playbook     = var.ansible_playbook
}

module "vmwindows" {
  source = "./modules/vmwindows-5877"

  prefix               = var.prefix
  location             = var.location
  rg_name              = module.rgroup.rg_name
  tags                 = local.common_tags
  subnet_id            = module.network.subnet_id
  vm_size              = var.vm_size
  vm_count             = var.windows_vm_count
  public_ip_sku        = var.public_ip_sku
  name_suffix          = var.name_suffix
  admin_username       = var.admin_username
  admin_password       = var.admin_password
  boot_diagnostics_uri = module.common.boot_diagnostics_uri
}

module "datadisk" {
  source = "./modules/datadisk-5877"

  prefix       = var.prefix
  location     = var.location
  rg_name      = module.rgroup.rg_name
  tags         = local.common_tags
  disk_size_gb = var.data_disk_size_gb
  vm_ids       = local.all_vm_ids
}

module "loadbalancer" {
  source = "./modules/loadbalancer-5877"

  prefix          = var.prefix
  location        = var.location
  rg_name         = module.rgroup.rg_name
  tags            = local.common_tags
  public_ip_sku   = var.public_ip_sku
  name_suffix     = var.name_suffix
  backend_nic_ids = module.vmlinux.nic_ids
}

module "database" {
  source = "./modules/database-5877"

  prefix         = var.prefix
  location       = var.location
  rg_name        = module.rgroup.rg_name
  tags           = local.common_tags
  name_suffix    = var.name_suffix
  admin_username = var.db_admin_username
  admin_password = var.db_admin_password
}
