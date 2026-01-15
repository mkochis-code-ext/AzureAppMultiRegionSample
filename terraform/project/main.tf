locals {
  resource_group_name = "rg-${var.workload}-${var.environment_prefix}-${var.location}-${var.suffix}"
  actual_data_location = var.data_location != "" ? var.data_location : var.location
}

# Resource Group
module "resource_group" {
  source = "../modules/azurerm/resource_group"

  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual Network
module "virtual_network" {
  source = "../modules/azurerm/virtual_network"

  name                = "vnet-${var.workload}-${var.environment_prefix}-${var.location}-${var.suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

# Subnets
module "subnet_app_integration" {
  source = "../modules/azurerm/subnet"

  name                 = "snet-app-integration"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = [var.app_subnet_address_prefix]
  
  delegation = {
    name = "delegation"
    service_delegation = {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

module "subnet_private_endpoints" {
  source = "../modules/azurerm/subnet"

  name                 = "snet-private-endpoints"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = [var.pe_subnet_address_prefix]
}

# Private DNS Zone for App Service
module "private_dns_app" {
  source = "../modules/azurerm/private_dns"

  name                = "privatelink.azurewebsites.net"
  resource_group_name = module.resource_group.name
  virtual_network_id  = module.virtual_network.id
  tags                = var.tags
}

# Private Endpoint for App Service
module "private_endpoint_app" {
  source = "../modules/azurerm/private_endpoint"

  name                           = "pe-app-${var.workload}-${var.environment_prefix}-${var.location}-${var.suffix}"
  resource_group_name            = module.resource_group.name
  location                       = module.resource_group.location
  subnet_id                      = module.subnet_private_endpoints.id
  private_connection_resource_id = module.app_service.id
  subresource_names              = ["sites"]
  private_dns_zone_ids           = [module.private_dns_app.id]
  tags                           = var.tags
}

# App Service
module "app_service" {
  source = "../modules/azurerm/app_service"

  name                       = "app-${var.workload}-${var.environment_prefix}-${var.location}-${var.suffix}"
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  sku_name                   = var.app_service_sku
  virtual_network_subnet_id  = module.subnet_app_integration.id
  tags                       = var.tags
}

# Network Security Group for App Service
# No specific inbound rules needed - traffic comes through Private Endpoint
module "nsg_app" {
  source = "../modules/azurerm/network_security_group"

  name                = "nsg-app-${var.workload}-${var.environment_prefix}-${var.location}-${var.suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  subnet_id           = module.subnet_app_integration.id
  
  security_rules = []
  
  tags = var.tags
}
