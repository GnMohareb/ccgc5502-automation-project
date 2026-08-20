# Azure Database for PostgreSQL - Flexible Server.
#
# The assignment specifies a *Single Server* instance. That product is retired
# and can no longer be provisioned on this subscription; `terraform apply`
# returned:
#
#   InvalidElasticServerType: The provided server type value
#   'Azure Database for PostgreSQL - Single Server' is invalid.
#
# Flexible Server is Microsoft's direct replacement and is used instead. The
# retired Single Server configuration is preserved next to this file as
# main-single-server.tf.disabled for reference.

locals {
  # Azure rejects names that start with a digit; "5877" does. This keeps the
  # ID digits while satisfying the "must start with a letter" rule.
  alpha_prefix = "n${var.prefix}"

  # Cheapest burstable tier, smallest supported storage.
  sku_name   = "B_Standard_B1ms"
  pg_version = "13"
  storage_mb = 32768
}

resource "azurerm_postgresql_flexible_server" "db" {
  name                = lower("${local.alpha_prefix}-psql-flex-${var.name_suffix}")
  location            = var.location
  resource_group_name = var.rg_name
  tags                = var.tags

  administrator_login    = var.admin_username
  administrator_password = var.admin_password

  sku_name   = local.sku_name
  version    = local.pg_version
  storage_mb = local.storage_mb

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  # No delegated subnet is configured, so the server is created with public
  # network access. Zone is left unset so Azure places it wherever capacity
  # allows in the region.
  lifecycle {
    ignore_changes = [zone]
  }
}
