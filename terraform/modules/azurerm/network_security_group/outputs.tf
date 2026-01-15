output "id" {
  description = "ID of the Network Security Group"
  value       = azurerm_network_security_group.main.id
}

output "name" {
  description = "Name of the Network Security Group"
  value       = azurerm_network_security_group.main.name
}
