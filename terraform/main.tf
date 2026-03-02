terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.56.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "LabCommon"
    storage_account_name = "common71977"
    container_name       = "terraform"
    key                  = "capstone.tfstate"
  }
}

provider "azurerm" {
  subscription_id = "ed0d83a3-7d5a-4c33-a5b0-5a342d235772"
  features {}
}

# Resource Group
resource "azurerm_resource_group" "capstone" {
  name     = "Capstone71977"
  location = "polandcentral"
}

resource "azurerm_cosmosdb_account" "CosmosDBaccount" {
  name                = "tfex-cosmosdb-account-71977" # Must be globally unique
  location            = azurerm_resource_group.capstone.location
  resource_group_name = azurerm_resource_group.capstone.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.capstone.location
    failover_priority = 0
  }
}

# Update your database and container to reference the RESOURCE, not the DATA source
resource "azurerm_cosmosdb_sql_database" "CosmosDBdatabase" {
  name                = "database"
  resource_group_name = azurerm_resource_group.capstone.name
  account_name        = azurerm_cosmosdb_account.CosmosDBaccount.name
}

resource "azurerm_cosmosdb_sql_container" "quotes_container" {
  name                  = "quotes-container"
  resource_group_name   = azurerm_resource_group.capstone.name
  account_name          = azurerm_cosmosdb_account.CosmosDBaccount.name
  database_name         = azurerm_cosmosdb_sql_database.CosmosDBdatabase.name
  partition_key_paths    = ["/id"] # Changed to match your 'id' requirement
  partition_key_version = 1
  throughput            = 400
}

# Client config data source

data "azurerm_client_config" "current" {}

# Key Vault to store connection string
resource "azurerm_key_vault" "kv" {
  name                        = "capstone-kv-71977"
  location                    = azurerm_resource_group.capstone.location
  resource_group_name         = azurerm_resource_group.capstone.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  enabled_for_disk_encryption = true
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = [
      "Get",
      "Set",
      "List"
    ]
  }
}

resource "azurerm_key_vault_secret" "cosmos_conn" {
  name         = "Cosmos-Connection-String"
  # Point to the RESOURCE name, not the DATA name
  value        = azurerm_cosmosdb_account.CosmosDBaccount.primary_sql_connection_string
  key_vault_id = azurerm_key_vault.kv.id
}

# Managed Identity for Web App
resource "azurerm_user_assigned_identity" "webapp_identity" {
  name                = "capstone-identity-71977"
  resource_group_name = azurerm_resource_group.capstone.name
  location            = azurerm_resource_group.capstone.location
}

# Grant identity access to Key Vault
resource "azurerm_key_vault_access_policy" "webapp_kv_access" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.webapp_identity.principal_id

  secret_permissions = [
    "Get", 
    "List" # Add this to help the Portal UI resolve the reference
  ]
}

# Service Plan (New Resource Type)
resource "azurerm_service_plan" "plan" {
  name                = "capstone-plan-71977"
  resource_group_name = azurerm_resource_group.capstone.name
  location            = azurerm_resource_group.capstone.location
  os_type             = "Linux"
  sku_name            = "S1"
}

# Linux Web App (New Resource Type)
resource "azurerm_linux_web_app" "webapp" {
  name                = "capstone-webapp-71977"
  resource_group_name = azurerm_resource_group.capstone.name
  location            = azurerm_resource_group.capstone.location
  service_plan_id     = azurerm_service_plan.plan.id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.webapp_identity.id]
  }

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    # Using versionless_id ensures the app always gets the latest secret version
    "COSMOS_CONN" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.cosmos_conn.versionless_id})"
  }

  key_vault_reference_identity_id = azurerm_user_assigned_identity.webapp_identity.id
}
