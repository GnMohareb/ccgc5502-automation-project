# One Windows Server 2016 VM in its own availability set.
# count is used here (rather than for_each) as the assignment requires.

locals {
  # Azure rejects names that start with a digit; "5877" does. This keeps the
  # ID digits while satisfying the "must start with a letter" rule.
  alpha_prefix = "n${var.prefix}"
  # The assignment specifies Windows Server 2016, which predates NVMe support
  # and cannot boot on the only VM sizes available to this subscription.
  # Windows Server 2022 Gen2 is used instead. See CHANGELOG section 11.
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-datacenter-g2"
  image_version   = "latest"
  os_disk_type    = "Standard_LRS"
}

resource "azurerm_availability_set" "win_avset" {
  name                         = "${var.prefix}-WIN-AVSET"
  location                     = var.location
  resource_group_name          = var.rg_name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true
  tags                         = var.tags
}

resource "azurerm_public_ip" "win_pip" {
  count = var.vm_count

  name                = "${var.prefix}-WVM${count.index + 1}-PIP"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = var.public_ip_sku
  domain_name_label   = lower("${local.alpha_prefix}-wvm${count.index + 1}-${var.name_suffix}")
  tags                = var.tags
}

resource "azurerm_network_interface" "win_nic" {
  count = var.vm_count

  name                = "${var.prefix}-WVM${count.index + 1}-NIC"
  location            = var.location
  resource_group_name = var.rg_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.win_pip[count.index].id
  }
}

resource "azurerm_windows_virtual_machine" "win_vm" {
  count = var.vm_count

  # Windows computer names are limited to 15 characters.
  name                  = "${var.prefix}-WVM${count.index + 1}"
  computer_name         = "${var.prefix}-WVM${count.index + 1}"
  location              = var.location
  resource_group_name   = var.rg_name
  size                  = var.vm_size
  availability_set_id   = azurerm_availability_set.win_avset.id
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.win_nic[count.index].id]
  tags                  = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = local.os_disk_type
  }

  source_image_reference {
    publisher = local.image_publisher
    offer     = local.image_offer
    sku       = local.image_sku
    version   = local.image_version
  }

  boot_diagnostics {
    storage_account_uri = var.boot_diagnostics_uri
  }
}

# Required extension - IaaS Antimalware.
resource "azurerm_virtual_machine_extension" "antimalware" {
  count = var.vm_count

  name                       = "IaaSAntimalware"
  virtual_machine_id         = azurerm_windows_virtual_machine.win_vm[count.index].id
  publisher                  = "Microsoft.Azure.Security"
  type                       = "IaaSAntimalware"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true
  tags                       = var.tags

  settings = jsonencode({
    AntimalwareEnabled        = true
    RealtimeProtectionEnabled = "true"
  })
}
