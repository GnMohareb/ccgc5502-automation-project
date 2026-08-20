# Public-facing load balancer fronting the three Linux VMs.
#
# NOTE ON SKU: the assignment specifies a *basic* load balancer, which is the
# default. Some subscriptions block Basic SKU public IPs entirely with
# "Cannot create more than 0 IPv4 Basic SKU public IP addresses"; on those,
# set var.public_ip_sku to "Standard". Run scripts/preflight.sh to check.

locals {
  # Azure rejects names that start with a digit; "5877" does. This keeps the
  # ID digits while satisfying the "must start with a letter" rule.
  alpha_prefix = "n${var.prefix}"
  probe_port   = 80
  backend_port = 80
}

resource "azurerm_public_ip" "lb_pip" {
  name                = "${var.prefix}-LB-PIP"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = var.public_ip_sku
  domain_name_label   = lower("${local.alpha_prefix}-lb-${var.name_suffix}")
  tags                = var.tags
}

resource "azurerm_lb" "lb" {
  name                = "${var.prefix}-LB"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = var.public_ip_sku
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "${var.prefix}-LB-FRONTEND"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "pool" {
  name            = "${var.prefix}-LB-BACKENDPOOL"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "probe" {
  name            = "${var.prefix}-LB-PROBE"
  loadbalancer_id = azurerm_lb.lb.id
  protocol        = "Tcp"
  port            = local.probe_port
}

resource "azurerm_lb_rule" "rule" {
  name                           = "${var.prefix}-LB-RULE-HTTP"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = local.backend_port
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool.id]
  probe_id                       = azurerm_lb_probe.probe.id
}

# Put each Linux NIC into the backend pool.
resource "azurerm_network_interface_backend_address_pool_association" "assoc" {
  for_each = var.backend_nic_ids

  network_interface_id    = each.value
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool.id
}
