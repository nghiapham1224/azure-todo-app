# MONITORING
# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
}

# Application Insights
resource "azurerm_application_insights" "appinsights" {
  name                = "insight-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
}

# Service Plan (Flex Consumption)
resource "azurerm_service_plan" "plan" {
  name                = "asp-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "FC1"
}

# Function App (Flex Consumption)
resource "azurerm_function_app_flex_consumption" "func" {
  name                          = "func-${var.prefix}-${var.environment}-${random_id.unique.hex}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  service_plan_id               = azurerm_service_plan.plan.id
  runtime_name                  = "python"
  runtime_version               = "3.11"
  storage_authentication_type   = "SystemAssignedIdentity"
  storage_container_type        = "blobContainer"
  storage_container_endpoint    = "${azurerm_storage_account.sa.primary_blob_endpoint}${azurerm_storage_container.deploy.name}"
  public_network_access_enabled = true
  virtual_network_subnet_id     = azurerm_subnet.snet_outbound.id
  identity {
    type = "SystemAssigned"
  }
  site_config {
    vnet_route_all_enabled = true # Necessary to reach Private Endpoints
    cors {
      allowed_origins = [
        "https://portal.azure.com"
      ]
    }
  }
  app_settings = {
    "MSSQL_CONNECTION_STRING" = "Driver={ODBC Driver 18 for SQL Server};Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.db.name};Authentication=ActiveDirectoryMsi;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
  }
  tags = {
    "hidden-link: /app-insights-resource-id" = azurerm_application_insights.appinsights.id
  }
}

# SECURITY & PERMISSIONS (RBAC)
# Grant Function access to Storage Blobs (Required to pull code)
resource "azurerm_role_assignment" "func_storage_blob_owner" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_function_app_flex_consumption.func.identity[0].principal_id
}

# Grant Function access to Storage Account (For host coordination)
resource "azurerm_role_assignment" "func_storage_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_function_app_flex_consumption.func.identity[0].principal_id
}

# Allow Function to send metrics/logs to App Insights
resource "azurerm_role_assignment" "func_monitoring_publisher" {
  scope                = azurerm_application_insights.appinsights.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_function_app_flex_consumption.func.identity[0].principal_id
}
