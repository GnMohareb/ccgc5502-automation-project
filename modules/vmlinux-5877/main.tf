# Three CentOS 8.2 VMs in a single availability set.
# for_each keeps the code scalable: add a name to var.vm_names and a complete
# VM (public IP, NIC, VM, extensions) is provisioned with it.

# Hardcoded here because they are not expected to change often.
locals {
  # Azure rejects names that start with a digit; "5877" does. This keeps the
  # ID digits while satisfying the "must start with a letter" rule.
  alpha_prefix = "n${var.prefix}"
  # The assignment specifies CentOS 8.2. Every VM size this subscription can
  # use is NVMe-only, and CentOS 8.2 (2020) predates NVMe support, so it cannot
  # boot. Rocky Linux 9 is the direct community successor to CentOS and boots on
  # NVMe. See CHANGELOG section 11.
  image_publisher = "resf"
  image_offer     = "rockylinux-x86_64"
  image_sku       = "9-lvm"
  image_version   = "latest"
  os_disk_type    = "Standard_LRS"
}

resource "azurerm_availability_set" "linux_avset" {
  name                         = "${var.prefix}-LINUX-AVSET"
  location                     = var.location
  resource_group_name          = var.rg_name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true
  tags                         = var.tags
}

resource "azurerm_public_ip" "linux_pip" {
  for_each = var.vm_names

  name                = "${var.prefix}-${upper(each.key)}-PIP"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = var.public_ip_sku
  domain_name_label   = lower("${local.alpha_prefix}-${each.key}-${var.name_suffix}")
  tags                = var.tags
}

resource "azurerm_network_interface" "linux_nic" {
  for_each = var.vm_names

  name                = "${var.prefix}-${upper(each.key)}-NIC"
  location            = var.location
  resource_group_name = var.rg_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linux_pip[each.key].id
  }
}

resource "azurerm_linux_virtual_machine" "linux_vm" {
  for_each = var.vm_names

  name                            = "${var.prefix}-${upper(each.key)}"
  computer_name                   = "${var.prefix}-${upper(each.key)}"
  location                        = var.location
  resource_group_name             = var.rg_name
  size                            = var.vm_size
  availability_set_id             = azurerm_availability_set.linux_avset.id
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.linux_nic[each.key].id]
  tags                            = var.tags

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

  # Ansible connects over this key, so the provisioning run is fully
  # non-interactive with no password anywhere on the command line.
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  boot_diagnostics {
    storage_account_uri = var.boot_diagnostics_uri
  }

  # Rocky Linux is published through the Azure Marketplace, which requires the
  # plan to be declared on the VM. Terms are accepted once per subscription with
  #   az vm image terms accept --publisher resf --offer rockylinux-x86_64 --plan 9-lvm
  plan {
    name      = local.image_sku
    product   = local.image_offer
    publisher = local.image_publisher
  }
}

# Required extension 1 of 2 - Network Watcher agent.
resource "azurerm_virtual_machine_extension" "netwatcher" {
  for_each = var.vm_names

  name                       = "NetworkWatcherAgentLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.linux_vm[each.key].id
  publisher                  = "Microsoft.Azure.NetworkWatcher"
  type                       = "NetworkWatcherAgentLinux"
  type_handler_version       = var.netwatcher_ext_version
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

# Required extension 2 of 2 - Azure Monitor agent.
resource "azurerm_virtual_machine_extension" "monitor" {
  for_each = var.vm_names

  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.linux_vm[each.key].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = var.monitor_ext_version
  auto_upgrade_minor_version = true
  tags                       = var.tags

  depends_on = [azurerm_virtual_machine_extension.netwatcher]
}
