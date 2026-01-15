variable "name" {
  description = "Name of the private DNS zone"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "virtual_network_id" {
  description = "Virtual network ID to link"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}
