variable "name" {
  description = "Name of the App Service"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "sku_name" {
  description = "SKU name for the service plan"
  type        = string
}

variable "virtual_network_subnet_id" {
  description = "Subnet ID for VNet integration"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}
