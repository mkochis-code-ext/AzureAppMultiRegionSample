variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "profile_name" {
  description = "The name of the Front Door Profile"
  type        = string
}

variable "endpoint_name" {
  description = "The name of the Front Door Endpoint"
  type        = string
}

variable "origin_group_name" {
  description = "The name of the Origin Group"
  type        = string
}

variable "sku_name" {
  description = "The SKU name of the Front Door Profile"
  type        = string
  default     = "Premium_AzureFrontDoor"
  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.sku_name)
    error_message = "SKU must be either Standard_AzureFrontDoor or Premium_AzureFrontDoor"
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "origins" {
  description = "A map of origins to define. Key is the name of the origin."
  type = map(object({
    host_name                      = string
    http_port                      = optional(number, 80)
    https_port                     = optional(number, 443)
    priority                       = optional(number, 1)
    weight                         = optional(number, 1000)
    certificate_name_check_enabled = optional(bool, true)
    enabled                        = optional(bool, true)
    private_link_target_id         = optional(string, null)
    private_link_location          = optional(string, null)
    private_link_request_message   = optional(string, "Front Door Private Link Request")
  }))
}

variable "health_probe_path" {
  description = "Path to probe for health checks"
  type        = string
  default     = "/"
}

variable "health_probe_protocol" {
  description = "Protocol to use for health checks"
  type        = string
  default     = "Http"
}

variable "load_balancing_sample_size" {
  type    = number
  default = 4
}

variable "load_balancing_successful_samples_required" {
  type    = number
  default = 3
}

variable "forwarding_protocol" {
  description = "Protocol to use for forwarding traffic"
  type        = string
  default     = "MatchRequest"
}
