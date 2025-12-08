# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.prefix}-${var.environment}"
  location = var.location
  tags = {
    environment = var.environment
    project     = var.prefix
  }
}

# Random ID (for globally unique names like storage)
resource "random_id" "unique" {
  byte_length = 4
}

# Storage Account (Required by Function app)
resource "azurerm_storage_account" "sa" {
  name                     = "sa${replace(var.prefix, "-", "")}${var.environment}${random_id.unique.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# App Service Plan (Serverless Consumption Plan)
resource "azurerm_service_plan" "plan" {
  name                = "asp-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "FC1"

}

# Azure Function App (Linux / Python)
resource "azurerm_linux_function_app" "func" {
  name                       = "func-${var.prefix}-${var.environment}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  service_plan_id            = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  site_config {
    application_stack {
      python_version = "3.12"
    }
    cors {
      allowed_origins = ["*"] # Allow all for now (dev), restricted in prod
    }
  }
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    MSSQL_CONNECTION_STRING  = "Driver={ODBC Driver 18 for SQL Server};Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.db.name};Uid=${azurerm_mssql_server.sql.administrator_login};Pwd=${azurerm_mssql_server.sql.administrator_login_password};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
  }
}

# SQL Server
resource "azurerm_mssql_server" "sql" {
  name                         = "sql-${var.prefix}-${var.environment}-${random_id.unique.hex}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password # Sourced securely from variable
}

# SQL Database
resource "azurerm_mssql_database" "db" {
  name      = "TodoDB"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "Basic"
}

# Firewall Rule (Allow Azure Services)
# Essential for the Function App to reach the SQL DB
resource "azurerm_mssql_firewall_rule" "allow_azure_ips" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Static Web App (Frontend)
resource "azurerm_static_web_app" "frontend" {
  name                = "swa-${var.prefix}-${var.environment}-${random_id.unique.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "eastus2" # Static Web Apps have limited region availability, 'eastus2' is a safe bet
  sku_tier            = "Standard"
  sku_size            = "Standard"
}
