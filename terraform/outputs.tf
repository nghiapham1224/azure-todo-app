output "function_app_name" {
  value = azurerm_function_app_flex_consumption.func.name
}

output "static_web_app_name" {
  value = azurerm_static_web_app.frontend.name
}

output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "swa_default_hostname" {
  value = azurerm_static_web_app.frontend.default_host_name
}

output "sql_server_hostname" {
  value = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "sql_database_name" {
  value = azurerm_mssql_database.db.name
}

output "function_app_url" {
  value = "https://${azurerm_function_app_flex_consumption.func.name}.azurewebsites.net"
}
