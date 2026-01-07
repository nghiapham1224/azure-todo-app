# Storage Account
resource "azurerm_storage_account" "sa" {
  name                          = "sa${var.prefix}${var.environment}${random_id.unique.hex}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = false
}

# Blob Deployment Container
resource "azurerm_storage_container" "deploy" {
  name                  = "app-package"
  container_access_type = "private"
  storage_account_id    = azurerm_storage_account.sa.id
}

# Storage Private Endpoint
resource "azurerm_private_endpoint" "pe_storage" {
  name                          = "pe-storage"
  custom_network_interface_name = "pe-storage-nic"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  subnet_id                     = azurerm_subnet.snet_private.id
  private_service_connection {
    name                           = "psc-storage"
    private_connection_resource_id = azurerm_storage_account.sa.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_blob.id]
  }
}

# SQL Admin Password
data "azurerm_key_vault_secret" "sql_password" {
  name         = "sql-password"
  key_vault_id = data.azurerm_key_vault.kv.id
}

# Get current public IP for SQL firewall
data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

# SQL Server
resource "azurerm_mssql_server" "sql" {
  name                          = "sql-${var.prefix}-${var.environment}-${random_id.unique.hex}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "12.0"
  public_network_access_enabled = true
  administrator_login           = "sqladmin"
  administrator_login_password  = data.azurerm_key_vault_secret.sql_password.value
  azuread_administrator {
    login_username = "AzureADAdmin"
    object_id      = var.aad_admin_object_id
  }
}

# SQL Firewall Rule (Allow local machine)
resource "azurerm_mssql_firewall_rule" "allow_local" {
  name             = "AllowLocalIP"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = chomp(data.http.myip.response_body)
  end_ip_address   = chomp(data.http.myip.response_body)
}

# SQL Database
resource "azurerm_mssql_database" "db" {
  name      = "TodoDB"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "Basic"
}

# SQL Private Endpoint
resource "azurerm_private_endpoint" "pe-sql" {
  name                          = "pe-sql"
  custom_network_interface_name = "pe-sql-nic"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  subnet_id                     = azurerm_subnet.snet_private.id
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
