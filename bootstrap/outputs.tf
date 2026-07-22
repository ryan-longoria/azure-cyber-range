output "resource_group_name" {
  value = azurerm_resource_group.terraform_state.name
}

output "storage_account_name" {
  value = azurerm_storage_account.terraform_state.name
}

output "container_name" {
  value = azurerm_storage_container.terraform_state.name
}

output "atlantis_url" {
  value = "https://${azurerm_container_app.atlantis.latest_revision_fqdn}"
}

output "atlantis_webhook_url" {
  value = "https://${azurerm_container_app.atlantis.latest_revision_fqdn}/events"
}

output "atlantis_identity_client_id" {
  value = azurerm_user_assigned_identity.atlantis.client_id
}

output "atlantis_identity_principal_id" {
  value = azurerm_user_assigned_identity.atlantis.principal_id
}

output "key_vault_name" {
  value = azurerm_key_vault.atlantis.name
}

output "atlantis_resource_group_name" {
  value = azurerm_resource_group.atlantis.name
}