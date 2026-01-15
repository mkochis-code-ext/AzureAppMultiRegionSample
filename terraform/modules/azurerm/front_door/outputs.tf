output "id" {
  description = "The ID of the Front Door Profile"
  value       = azurerm_cdn_frontdoor_profile.main.id
}

output "endpoint_host_name" {
  description = "The host name of the Front Door Endpoint"
  value       = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "endpoint_url" {
  description = "The URL of the Front Door Endpoint"
  value       = "https://${azurerm_cdn_frontdoor_endpoint.main.host_name}"
}
