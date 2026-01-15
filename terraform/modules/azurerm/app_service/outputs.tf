output "id" {
  description = "ID of the App Service"
  value       = azurerm_linux_web_app.main.id
}

output "name" {
  description = "Name of the App Service"
  value       = azurerm_linux_web_app.main.name
}

output "default_hostname" {
  description = "Default hostname"
  value       = azurerm_linux_web_app.main.default_hostname
}

output "identity_principal_id" {
  description = "Principal ID of managed identity"
  value       = azurerm_linux_web_app.main.identity[0].principal_id
}
