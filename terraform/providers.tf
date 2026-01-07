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
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {
    container_name       = "tfstate"
    key                  = "todo-dev.tfstate"
    storage_account_name = "tfstate1756664581"
    use_azuread_auth     = true
    # Will be configured by pipeline
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "7e3747e0-7e48-4d2a-9ed3-8323092272b8" # Explicitly set subscription if needed, or rely on env vars
}
