output "id" {
  description = "ID of the private endpoint"
  value       = azurerm_private_endpoint.main.id
}

output "name" {
  description = "Name of the private endpoint"
  value       = azurerm_private_endpoint.main.name
}

output "private_ip_address" {
  description = "Private IP address"
  value       = azurerm_private_endpoint.main.private_service_connection[0].private_ip_address
}
