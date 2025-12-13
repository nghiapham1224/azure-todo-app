resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.prefix}-${var.environment}"
  location = var.location
}

resource "random_id" "unique" {
  byte_length = 4
}

# --- Key Vault for SQL Password ---
data "azurerm_key_vault" "kv" {
  name                = "terraform-kv-01"
  resource_group_name = "terraform-state-rg"
}

data "azurerm_key_vault_secret" "sql_password" {
  name         = "sql-password"
  key_vault_id = data.azurerm_key_vault.kv.id
}


# --- Networking ---
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.prefix}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet for Function App (Delegated)
resource "azurerm_subnet" "snet_func" {
  name                 = "snet-func"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Subnet for Private Endpoints (SQL)
resource "azurerm_subnet" "snet_private" {
  name                 = "snet-private"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Private DNS Zone for SQL
resource "azurerm_private_dns_zone" "dns_sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "link-to-vnet"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_sql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# --- Monitoring ---
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.prefix}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appinsights" {
  name                = "insight-${var.prefix}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
}

# --- Database ---
resource "azurerm_mssql_server" "sql" {
  name                         = "sql-${var.prefix}-${var.environment}-${random_id.unique.hex}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = data.azurerm_key_vault_secret.sql_password.value # Use secret from Key Vault

  # Disable Public Access (Security Best Practice)
  public_network_access_enabled = false

  azuread_administrator {
    login_username = "AzureADAdmin"
    object_id      = var.aad_admin_object_id
  }
}

resource "azurerm_mssql_database" "db" {
  name      = "TodoDB"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "Basic"
}

# Private Endpoint for SQL
resource "azurerm_private_endpoint" "pe_sql" {
  name                = "pe-sql-${var.prefix}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_private.id

  private_service_connection {
    name                           = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_sql.id]
  }
}

# --- Compute (Function App) ---
resource "azurerm_storage_account" "sa" {
  name                     = "sa${replace(var.prefix, "-", "")}${var.environment}${random_id.unique.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "deploy" {
  name                  = "deployment-package"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

resource "azurerm_service_plan" "plan" {
  name                = "asp-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "FC1" # Flex Consumption
}

resource "azurerm_function_app_flex_consumption" "func" {
  name                = "func-${var.prefix}-${var.environment}-${random_id.unique.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.plan.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.sa.primary_blob_endpoint}${azurerm_storage_container.deploy.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.sa.primary_access_key

  runtime_name    = "python"
  runtime_version = "3.13"

  # VNet Integration
  virtual_network_subnet_id = azurerm_subnet.snet_func.id

  # Managed Identity
  identity {
    type = "SystemAssigned"
  }

  site_config {
    cors {
      allowed_origins = ["*"] # Will be restricted by Pipeline script later
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.appinsights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.appinsights.connection_string
    "AzureWebJobsStorage"            = azurerm_storage_account.sa.primary_connection_string
    # Connection String with Managed Identity
    "MSSQL_CONNECTION_STRING" = "Driver={ODBC Driver 18 for SQL Server};Server=${azurerm_mssql_server.sql.fully_qualified_domain_name};Database=${azurerm_mssql_database.db.name};Authentication=ActiveDirectoryMsi;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
  }

  tags = {
      "hidden-link:${azurerm_application_insights.appinsights.id}" = "Resource"
      "Name"                                                       = "My Functions App"
    }
}

# Grant Function App access to Storage Blob Data (for deployment & runtime)
resource "azurerm_role_assignment" "func_storage_blob_owner" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_function_app_flex_consumption.func.identity[0].principal_id
}

# --- Frontend (Static Web App) ---
resource "azurerm_static_web_app" "frontend" {
  name                = "swa-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "eastus2"
  sku_tier            = "Free"
  sku_size            = "Free"
}

resource "azurerm_key_vault_secret" "swa_token" {
  name         = "swa-token-${var.prefix}-${var.environment}"
  value        = azurerm_static_web_app.frontend.api_key
  key_vault_id = data.azurerm_key_vault.kv.id
}
