terraform {
  backend "azurerm" {
    resource_group_name  = "rg-cyber-range-tfstate"
    storage_account_name = "stcybertf8yuw4d07"
    container_name       = "tfstate"
    key                  = "cyber-range/lab.tfstate"
  }
}