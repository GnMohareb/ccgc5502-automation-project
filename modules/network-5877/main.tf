# Virtual network, one subnet, and an NSG opening the four required ports.
#
# The four inbound rules are declared as inline security_rule blocks rather
# than as separate azurerm_network_security_rule resources. Both forms produce
# the same four rules in Azure; the inline form keeps the resource count in
# state at the 48 the assignment requires.

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-VNET"
  location            = var.location
  resource_group_name = var.rg_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-SUBNET"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.subnet_address_prefixes
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-NSG"
  location            = var.location
  resource_group_name = var.rg_name
  tags                = var.tags

  # One inbound allow rule per port in var.allowed_ports.
  # Priorities start at 100 and step by 10.
  dynamic "security_rule" {
    for_each = { for idx, port in var.allowed_ports : port => idx }

    content {
      name                       = "Allow-TCP-${security_rule.key}"
      priority                   = 100 + (security_rule.value * 10)
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.key
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
