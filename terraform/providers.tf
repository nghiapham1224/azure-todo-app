terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  # This backend block tells Terraform where to store its state file
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
