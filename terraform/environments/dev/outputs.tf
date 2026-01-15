output "front_door_endpoint_url" {
  description = "The endpoint URL of the Front Door"
  value       = module.front_door.endpoint_url
}

output "primary_resource_group_name" {
  description = "Primary region resource group name"
  value       = module.project_primary.resource_group_name
}

output "secondary_resource_group_name" {
  description = "Secondary region resource group name"
  value       = module.project_secondary.resource_group_name
}

output "primary_region" {
  description = "Primary region location"
  value       = var.primary_location
}

output "secondary_region" {
  description = "Secondary region location"
  value       = var.secondary_location
}

output "primary_app_service_name" {
  description = "Primary App Service name"
  value       = module.project_primary.app_service_name
}

output "secondary_app_service_name" {
  description = "Secondary App Service name"
  value       = module.project_secondary.app_service_name
}


