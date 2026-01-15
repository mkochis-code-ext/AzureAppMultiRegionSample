variable "name" {
  description = "Name of the private endpoint"
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

variable "subnet_id" {
  description = "Subnet ID for the private endpoint"
  type        = string
}

variable "private_connection_resource_id" {
  description = "Resource ID to connect to"
  type        = string
}

variable "subresource_names" {
  description = "Subresource names"
  type        = list(string)
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}
