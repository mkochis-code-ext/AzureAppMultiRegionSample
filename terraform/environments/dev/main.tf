terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Generate random suffix for uniqueness
resource "random_string" "suffix" {
  length  = 3
  special = false
  upper   = false
}

locals {
  suffix = random_string.suffix.result
  tags = merge(
    var.tags,
    {
      Environment = var.environment_prefix
      ManagedBy   = "Terraform"
    }
  )
}

# Global Resource Group for Front Door
resource "azurerm_resource_group" "global" {
  name     = "rg-global-${var.workload}-${var.environment_prefix}-${local.suffix}"
  location = var.primary_location # Front Door is global, but the RG needs a location
  tags     = local.tags
}

# Primary Region
module "project_primary" {
  source = "../../project"

  environment_prefix = var.environment_prefix
  suffix             = local.suffix
  tags               = local.tags
  workload           = var.workload
  location           = var.primary_location
  data_location      = var.data_location

  # Network configuration
  vnet_address_space            = var.vnet_address_space_primary
  app_subnet_address_prefix     = var.app_subnet_address_prefix_primary
  pe_subnet_address_prefix      = var.pe_subnet_address_prefix_primary

  # App Service configuration
  app_service_sku = var.app_service_sku
}

# Secondary Region
module "project_secondary" {
  source = "../../project"

  environment_prefix = var.environment_prefix
  suffix             = local.suffix
  tags               = local.tags
  workload           = var.workload
  location           = var.secondary_location
  data_location      = var.data_location

  # Network configuration
  vnet_address_space            = var.vnet_address_space_secondary
  app_subnet_address_prefix     = var.app_subnet_address_prefix_secondary
  pe_subnet_address_prefix      = var.pe_subnet_address_prefix_secondary

  # App Service configuration
  app_service_sku = var.app_service_sku
}

# Front Door Module
module "front_door" {
  source = "../../modules/azurerm/front_door"

  resource_group_name = azurerm_resource_group.global.name
  profile_name        = "afd-${var.workload}-${var.environment_prefix}-${local.suffix}"
  endpoint_name       = "afd-endpoint-${local.suffix}"
  origin_group_name   = "afd-origin-group"
  sku_name            = "Premium_AzureFrontDoor"
  
  health_probe_protocol = "Https"
  forwarding_protocol   = "HttpsOnly"

  tags = local.tags

  origins = {
    "primary" = {
      host_name                      = module.project_primary.app_service_default_hostname
      priority                       = 1
      weight                         = 1000
      certificate_name_check_enabled = true
      private_link_target_id         = module.project_primary.app_service_id
      private_link_location          = var.primary_location
    },
    "secondary" = {
      host_name                      = module.project_secondary.app_service_default_hostname
      priority                       = 2
      weight                         = 1000
      certificate_name_check_enabled = true
      private_link_target_id         = module.project_secondary.app_service_id
      private_link_location          = var.secondary_location
    }
  }
}


