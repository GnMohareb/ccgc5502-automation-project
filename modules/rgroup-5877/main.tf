# One resource group to hold the whole assignment deployment.
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-${upper(var.name_suffix)}-RG"
  location = var.location
  tags     = var.tags
}
