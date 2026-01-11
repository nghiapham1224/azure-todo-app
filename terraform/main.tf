# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.prefix}-${var.environment}"
  location = var.location
}

# Random ID
resource "random_id" "unique" {
  byte_length = 4
}
