resource "null_resource" "post_deployment_configuration" {
  triggers = {
    func_hostname = azurerm_function_app_flex_consumption.func.default_hostname
    swa_hostname  = azurerm_static_web_app.frontend.default_host_name
    # Trigger whenever the frontend or compute configuration changes
    frontend_id = azurerm_static_web_app.frontend.id
    func_id     = azurerm_function_app_flex_consumption.func.id
  }

  depends_on = [
    azurerm_static_web_app.frontend,
    azurerm_function_app_flex_consumption.func
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Configuring Static Web App API_URL..."
      az staticwebapp appsettings set \
        --name ${azurerm_static_web_app.frontend.name} \
        --resource-group ${azurerm_resource_group.rg.name} \
        --setting-names API_URL="https://${azurerm_function_app_flex_consumption.func.default_hostname}/api/todos"

      echo "Configuring Function App CORS..."
      az functionapp cors add \
        --name ${azurerm_function_app_flex_consumption.func.name} \
        --resource-group ${azurerm_resource_group.rg.name} \
        --allowed-origins "https://${azurerm_static_web_app.frontend.default_host_name}"
    EOT
  }
}
