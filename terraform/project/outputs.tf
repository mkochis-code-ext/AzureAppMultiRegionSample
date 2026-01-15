output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.resource_group.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = module.resource_group.id
}

output "app_service_name" {
  description = "Name of the App Service"
  value       = module.app_service.name
}

output "app_service_id" {
  description = "ID of the App Service"
  value       = module.app_service.id
}

output "app_service_default_hostname" {
  description = "Default hostname of the App Service"
  value       = module.app_service.default_hostname
}

output "app_service_identity_principal_id" {
  description = "Principal ID of the App Service managed identity"
  value       = module.app_service.identity_principal_id
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = module.virtual_network.id
}

output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = module.virtual_network.name
}
