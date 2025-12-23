# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.prefix}-${var.environment}"
  location = var.location
}

# Random ID
resource "random_id" "unique" {
  byte_length = 4
}

# Key Vault
data "azurerm_key_vault" "kv" {
  name                = "terraform-kv-01"
  resource_group_name = "terraform-state-rg"
}
