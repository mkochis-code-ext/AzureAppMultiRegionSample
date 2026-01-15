variable "name" {
  description = "Name of the subnet"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "virtual_network_name" {
  description = "Virtual network name"
  type        = string
}

variable "address_prefixes" {
  description = "Address prefixes for the subnet"
  type        = list(string)
}

variable "delegation" {
  description = "Optional delegation configuration"
  type = object({
    name = string
    service_delegation = object({
      name    = string
      actions = list(string)
    })
  })
  default = null
}
