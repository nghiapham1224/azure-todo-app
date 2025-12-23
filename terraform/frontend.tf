# Static Web App
resource "azurerm_static_web_app" "frontend" {
  name                = "swa-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_tier            = "Free"
}

# Store Deployment Token in Key Vault
# This saves the API key needed for your GitHub Actions/Azure Pipelines
resource "azurerm_key_vault_secret" "swa_token" {
  name         = "swa-token-${var.prefix}-${var.environment}"
  value        = azurerm_static_web_app.frontend.api_key
  key_vault_id = data.azurerm_key_vault.kv.id
}
