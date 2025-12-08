terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0" # Upgraded to support Flex Consumption
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {
    container_name       = "tfstate"
    key                  = "todo-dev.tfstate"
    storage_account_name = "tfstate12072025"
    use_azuread_auth     = true
    # Will be configured by pipeline
  }
}

provider "azurerm" {
  features {}
  subscription_id = "712c5cd3-626a-449d-93bc-d2bd155dc864" # Explicitly set subscription if needed, or rely on env vars
}
