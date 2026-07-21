data "azurerm_resource_group" "cyber_range" {
  name = "rg-cyber-range-lab"
}

resource "azurerm_role_assignment" "atlantis_subscription_owner" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Owner"
  principal_id         = azurerm_user_assigned_identity.atlantis.principal_id
}

resource "azurerm_role_assignment" "atlantis_state_blob_contributor" {
  scope                = azurerm_storage_account.terraform_state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.atlantis.principal_id
}