terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-5877"
    storage_account_name = "sttf5877d78defd8"
    container_name       = "tfstate"
    key                  = "assignment2-5877.terraform.tfstate"
  }
}
