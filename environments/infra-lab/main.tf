resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-infra-lab"
  location = "East US"
}

resource "azurerm_storage_account" "lab" {
  name                     = "infralab${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "profiles" {
  name                 = "profiles"
  storage_account_id   = azurerm_storage_account.lab.id
  quota                = 50
}