variable "prefix" {
  description = "A unique prefix for all resources"
  type        = string
  default     = "todo"
}

variable "environment" {
  description = "Environment (dev, prod, etc.)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "sql_admin_password" {
  description = "Password for SQL Server Admin"
  type        = string
  sensitive   = true
  default     = "Khong123!"
}
