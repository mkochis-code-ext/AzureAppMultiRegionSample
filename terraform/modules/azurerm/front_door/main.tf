resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = var.profile_name
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = var.endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "main" {
  name                     = var.origin_group_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  session_affinity_enabled = true

  load_balancing {
    sample_size                 = var.load_balancing_sample_size
    successful_samples_required = var.load_balancing_successful_samples_required
  }

  health_probe {
    path                = var.health_probe_path
    protocol            = var.health_probe_protocol
    request_type        = "HEAD"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "main" {
  for_each = var.origins

  name                          = each.key
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id

  enabled                        = each.value.enabled
  host_name                      = each.value.host_name
  http_port                      = each.value.http_port
  https_port                     = each.value.https_port
  origin_host_header             = each.value.host_name
  priority                       = each.value.priority
  weight                         = each.value.weight
  certificate_name_check_enabled = each.value.certificate_name_check_enabled

  # Private Link configuration (Premium SKU only)
  dynamic "private_link" {
    for_each = each.value.private_link_target_id != null ? [1] : []
    content {
      target_type       = "sites" # App Service
      location          = each.value.private_link_location
      request_message   = each.value.private_link_request_message
      private_link_target_id = each.value.private_link_target_id
    }
  }
}


resource "azurerm_cdn_frontdoor_route" "main" {
  name                          = "${var.endpoint_name}-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  
  cdn_frontdoor_origin_ids      = [for origin in azurerm_cdn_frontdoor_origin.main : origin.id]

  supported_protocols           = ["Http", "Https"]
  patterns_to_match             = ["/*"]
  forwarding_protocol           = var.forwarding_protocol

  link_to_default_domain = true
  https_redirect_enabled = var.forwarding_protocol != "HttpOnly" ? true : false
}

# Approve Private Link connections automatically
# Note: This requires a sleep to allow Azure to create the pending connection
resource "null_resource" "approve_private_link" {
  for_each = var.origins

  triggers = {
    origin_id = azurerm_cdn_frontdoor_origin.main[each.key].id
    private_link_target_id = each.value.private_link_target_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Check if Private Link is configured
      $targetId = "${each.value.private_link_target_id}"
      if ([string]::IsNullOrEmpty($targetId)) {
        Write-Host "Skipping ${each.key} - no Private Link configured"
        exit 0
      }
      
      # Wait for Private Link connection to be created
      Start-Sleep -Seconds 30
      
      # Extract resource details from target ID
      $parts = $targetId -split '/'
      $rgName = $parts[4]
      $appName = $parts[8]
      
      # Find and approve pending connection from Front Door
      Write-Host "Looking for pending Private Link connection on $appName..."
      $connections = az network private-endpoint-connection list `
        --name $appName `
        --resource-group $rgName `
        --type Microsoft.Web/sites `
        --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].name" `
        -o tsv
      
      foreach ($conn in $connections) {
        Write-Host "Approving connection: $conn"
        az network private-endpoint-connection approve `
          --name $conn `
          --resource-group $rgName `
          --resource-name $appName `
          --type Microsoft.Web/sites `
          --description "Auto-approved by Terraform"
      }
      
      Write-Host "Private Link approval complete for $appName"
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [azurerm_cdn_frontdoor_origin.main]
}
