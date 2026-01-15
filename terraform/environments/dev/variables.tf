variable "environment_prefix" {
  description = "Environment prefix (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "workload" {
  description = "Workload name"
  type        = string
  default     = "webapp"
}

variable "primary_location" {
  description = "Primary Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "secondary_location" {
  description = "Secondary Azure region for resources"
  type        = string
  default     = "westus"
}

variable "data_location" {
  description = "Azure region for data resources (defaults to location if not specified)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project    = "Azure App Sample"
    Owner      = "Platform Team"
    CostCenter = "Engineering"
  }
}

# Network Configuration
variable "vnet_address_space_primary" {
  description = "Address space for the primary virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_subnet_address_prefix_primary" {
  description = "Address prefix for App Service integration subnet (primary)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "pe_subnet_address_prefix_primary" {
  description = "Address prefix for Private Endpoints subnet (primary)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "vnet_address_space_secondary" {
  description = "Address space for the secondary virtual network"
  type        = string
  default     = "10.1.0.0/16"
}

variable "app_subnet_address_prefix_secondary" {
  description = "Address prefix for App Service integration subnet (secondary)"
  type        = string
  default     = "10.1.1.0/24"
}

variable "pe_subnet_address_prefix_secondary" {
  description = "Address prefix for Private Endpoints subnet (secondary)"
  type        = string
  default     = "10.1.3.0/24"
}

# App Service Configuration
variable "app_service_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "B1"
}
