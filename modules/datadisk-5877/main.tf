# One managed data disk per VM, attached to that VM.
# Driven by a map so the same module serves both the Linux and Windows VMs.

locals {
  disk_type = "Standard_LRS"
}

resource "azurerm_managed_disk" "data" {
  for_each = var.vm_ids

  name                 = "${var.prefix}-${upper(each.key)}-DATADISK"
  location             = var.location
  resource_group_name  = var.rg_name
  storage_account_type = local.disk_type
  create_option        = "Empty"
  disk_size_gb         = var.disk_size_gb
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "data_attach" {
  for_each = var.vm_ids

  managed_disk_id    = azurerm_managed_disk.data[each.key].id
  virtual_machine_id = each.value
  lun                = index(sort(keys(var.vm_ids)), each.key)
  caching            = "ReadWrite"
}
