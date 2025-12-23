output "function_app_name" {
  value = azurerm_function_app_flex_consumption.func.name
}

output "static_web_app_name" {
  value = azurerm_static_web_app.frontend.name
}

output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}
