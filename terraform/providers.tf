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
  # Backend configuration
  # UPDATE THESE VALUES BEFORE INITIALIZATION
  # Note: Must be a literal string; variables are not allowed here.
  backend "azurerm" {
    storage_account_name = "tfstate1756664581"
    container_name       = "tfstate"
    key                  = "todo-dev.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
}
