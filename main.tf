resource "azurerm_resource_group" "cyber_range" {
  name     = "rg-cyber-range-lab"
  location = "southcentralus"

  tags = {
    project     = "azure-cyber-range"
    environment = "lab"
    managed_by  = "terraform"
  }
}