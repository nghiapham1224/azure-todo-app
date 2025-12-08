variable "prefix" {
  type        = string
  description = "Project prefix"
  default     = "todo"
}

variable "environment" {
  type        = string
  description = "Environment (dev, prod)"
  default     = "dev"
}

variable "location" {
  type        = string
  description = "Azure Region"
  default     = "eastus2"
}

# Removed sql_admin_password variable as it's now fetched from Key Vault

variable "aad_admin_object_id" {
  type        = string
  description = "Object ID of the Azure AD Admin for SQL"
  default     = "476e07a0-1245-4c8d-81b3-5abe17f2c0e6" # Your ID
}
