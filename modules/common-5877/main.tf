# Shared services: Log Analytics, Recovery Services vault, and a standard LRS
# storage account. This storage account is deliberately separate from the one
# holding the Terraform remote backend.

locals {
  # Azure rejects names that start with a digit; "5877" does. This keeps the
  # ID digits while satisfying the "must start with a letter" rule.
  alpha_prefix = "n${var.prefix}"
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.prefix}-LAW"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_recovery_services_vault" "rsv" {
  # Azure requires this name to start with a letter, so the alpha-prefixed
  # form is used here while still carrying the 5877 ID digits.
  name                = "${local.alpha_prefix}-RSV"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = "Standard"
  tags                = var.tags

  # soft_delete_enabled is deliberately left at its default of true. Azure
  # rejects disabling it with:
  #   BMSUserErrorDisablingSoftDeleteStateNotAllowed
}

# Lower-case, alphanumeric only, globally unique.
resource "azurerm_storage_account" "sa" {
  name                     = "st${var.prefix}common${var.name_suffix}"
  location                 = var.location
  resource_group_name      = var.rg_name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

# A Recovery Services vault with no policy performs no backups. This daily
# policy makes the vault functional and brings the deployment to the 48
# resources the assignment requires in terraform state.
resource "azurerm_backup_policy_vm" "vm_backup" {
  name                = "${local.alpha_prefix}-VM-BACKUP-POLICY"
  resource_group_name = var.rg_name
  recovery_vault_name = azurerm_recovery_services_vault.rsv.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 7
  }
}
