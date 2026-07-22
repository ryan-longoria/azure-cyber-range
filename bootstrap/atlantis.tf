resource "azurerm_resource_group" "atlantis" {
  name     = "rg-atlantis-platform"
  location = var.location

  tags = {
    project    = "azure-cyber-range"
    component  = "atlantis"
    managed_by = "terraform"
  }
}

resource "azurerm_log_analytics_workspace" "atlantis" {
  name                = "law-atlantis"
  location            = azurerm_resource_group.atlantis.location
  resource_group_name = azurerm_resource_group.atlantis.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "atlantis" {
  name                       = "cae-atlantis"
  location                   = azurerm_resource_group.atlantis.location
  resource_group_name        = azurerm_resource_group.atlantis.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.atlantis.id
}

resource "azurerm_user_assigned_identity" "atlantis" {
  name                = "id-atlantis"
  location            = azurerm_resource_group.atlantis.location
  resource_group_name = azurerm_resource_group.atlantis.name
}

resource "random_string" "atlantis_storage_suffix" {
  length  = 8
  upper   = false
  special = false
}

resource "azurerm_storage_account" "atlantis" {
  name                     = "statlantis${random_string.atlantis_storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.atlantis.name
  location                 = azurerm_resource_group.atlantis.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = {
    project    = "azure-cyber-range"
    component  = "atlantis"
    managed_by = "terraform"
  }
}

resource "azurerm_storage_share" "atlantis" {
  name               = "atlantis-data"
  storage_account_id = azurerm_storage_account.atlantis.id
  quota              = 10
}

resource "azurerm_container_app_environment_storage" "atlantis" {
  name                         = "atlantis-data"
  container_app_environment_id = azurerm_container_app_environment.atlantis.id

  account_name = azurerm_storage_account.atlantis.name
  share_name   = azurerm_storage_share.atlantis.name
  access_key   = azurerm_storage_account.atlantis.primary_access_key
  access_mode  = "ReadWrite"
}

resource "random_string" "key_vault_suffix" {
  length  = 8
  upper   = false
  special = false
}

resource "azurerm_key_vault" "atlantis" {
  name                       = "kv-atlantis-${random_string.key_vault_suffix.result}"
  location                   = azurerm_resource_group.atlantis.location
  resource_group_name        = azurerm_resource_group.atlantis.name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = {
    project    = "azure-cyber-range"
    component  = "atlantis"
    managed_by = "terraform"
  }
}

resource "azurerm_role_assignment" "atlantis_key_vault_secrets_user" {
  scope                = azurerm_key_vault.atlantis.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.atlantis.principal_id
}

data "azurerm_key_vault_secret" "github_app_key" {
  name         = "github-app-key"
  key_vault_id = azurerm_key_vault.atlantis.id

  depends_on = [
    azurerm_role_assignment.atlantis_key_vault_secrets_user
  ]
}

data "azurerm_key_vault_secret" "github_webhook_secret" {
  name         = "github-webhook-secret"
  key_vault_id = azurerm_key_vault.atlantis.id

  depends_on = [
    azurerm_role_assignment.atlantis_key_vault_secrets_user
  ]
}

resource "azurerm_container_app" "atlantis" {
  name                         = "ca-atlantis"
  container_app_environment_id = azurerm_container_app_environment.atlantis.id
  resource_group_name          = azurerm_resource_group.atlantis.name
  revision_mode                = "Single"

  identity {
    type = "UserAssigned"

    identity_ids = [
      azurerm_user_assigned_identity.atlantis.id
    ]
  }

  secret {
    name                = "github-app-key"
    key_vault_secret_id = data.azurerm_key_vault_secret.github_app_key.versionless_id
    identity            = azurerm_user_assigned_identity.atlantis.id
  }

  secret {
    name                = "github-webhook-secret"
    key_vault_secret_id = data.azurerm_key_vault_secret.github_webhook_secret.versionless_id
    identity            = azurerm_user_assigned_identity.atlantis.id
  }

  secret {
    name                = "terraform-backend-access-key"
    key_vault_secret_id = data.azurerm_key_vault_secret.terraform_backend_access_key.versionless_id
    identity            = azurerm_user_assigned_identity.atlantis.id
  }

  secret {
    name                = "terraform-arm-client-id"
    key_vault_secret_id = data.azurerm_key_vault_secret.terraform_arm_client_id.versionless_id
    identity            = azurerm_user_assigned_identity.atlantis.id
    }

    secret {
    name                = "terraform-arm-client-secret"
    key_vault_secret_id = data.azurerm_key_vault_secret.terraform_arm_client_secret.versionless_id
    identity            = azurerm_user_assigned_identity.atlantis.id
    }

  ingress {
    external_enabled = true
    target_port      = 4141
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "atlantis"
      image  = var.atlantis_image
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "HOME"
        value = "/home/atlantis"
      }

      env {
        name  = "ATLANTIS_PORT"
        value = "4141"
      }

      env {
        name  = "ATLANTIS_DATA_DIR"
        value = "/home/atlantis/.atlantis"
      }

      env {
        name  = "ATLANTIS_REPO_ALLOWLIST"
        value = "github.com/${var.github_owner}/${var.github_repository}"
      }

      env {
        name = "ATLANTIS_REPO_CONFIG_JSON"

        value = jsonencode({
          repos = [
            {
              id = "github.com/${var.github_owner}/${var.github_repository}"
              allowed_overrides = [
                "workflow",
                "apply_requirements"
              ]
              allow_custom_workflows = true
            }
          ]
        })
      }

      env {
        name  = "ATLANTIS_GH_APP_ID"
        value = var.github_app_id
      }

      env {
        name        = "ATLANTIS_GH_APP_KEY"
        secret_name = "github-app-key"
      }

      env {
        name        = "ATLANTIS_GH_WEBHOOK_SECRET"
        secret_name = "github-webhook-secret"
      }

      env {
        name  = "ATLANTIS_ATLANTIS_URL"
        value = "https://ca-atlantis.${azurerm_container_app_environment.atlantis.default_domain}"
      }

      env {
        name  = "ATLANTIS_LOG_LEVEL"
        value = "info"
      }

      env {
        name  = "ATLANTIS_ALLOW_FORK_PRS"
        value = "false"
      }

      env {
        name  = "ATLANTIS_ALLOW_DRAFT_PRS"
        value = "false"
      }

      env {
        name  = "ATLANTIS_DISABLE_APPLY_ALL"
        value = "true"
      }

      env {
        name  = "ATLANTIS_SILENCE_NO_PROJECTS"
        value = "true"
      }

      env {
        name  = "ATLANTIS_WRITE_GIT_CREDS"
        value = "true"
      }

        env {
        name        = "ARM_CLIENT_ID"
        secret_name = "terraform-arm-client-id"
        }

        env {
        name        = "ARM_CLIENT_SECRET"
        secret_name = "terraform-arm-client-secret"
        }

      env {
        name  = "ARM_TENANT_ID"
        value = var.tenant_id
      }

      env {
        name  = "ARM_SUBSCRIPTION_ID"
        value = var.subscription_id
      }

      env {
        name        = "ARM_ACCESS_KEY"
        secret_name = "terraform-backend-access-key"
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.atlantis_key_vault_secrets_user,
    azurerm_container_app_environment_storage.atlantis
  ]
}

data "azurerm_key_vault_secret" "terraform_backend_access_key" {
  name         = "terraform-backend-access-key"
  key_vault_id = azurerm_key_vault.atlantis.id

  depends_on = [
    azurerm_role_assignment.atlantis_key_vault_secrets_user
  ]
}

data "azurerm_key_vault_secret" "terraform_arm_client_id" {
  name         = "terraform-arm-client-id"
  key_vault_id = azurerm_key_vault.atlantis.id

  depends_on = [
    azurerm_role_assignment.atlantis_key_vault_secrets_user
  ]
}

data "azurerm_key_vault_secret" "terraform_arm_client_secret" {
  name         = "terraform-arm-client-secret"
  key_vault_id = azurerm_key_vault.atlantis.id

  depends_on = [
    azurerm_role_assignment.atlantis_key_vault_secrets_user
  ]
}