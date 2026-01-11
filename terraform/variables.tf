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

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
  default     = "7e3747e0-7e48-4d2a-9ed3-8323092272b8"
}

variable "aad_admin_object_id" {
  type        = string
  description = "Object ID of the Azure AD Admin for SQL"
  default     = "476e07a0-1245-4c8d-81b3-5abe17f2c0e6"
}
