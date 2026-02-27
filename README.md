# Azure App Multi-Region Sample - Terraform Infrastructure

> **Disclaimer:** This repository is provided purely as a demonstration of these workflows. You are free to use, modify, and adapt the code as you see fit; however, it is offered as-is with no warranty or support of any kind. Use it at your own risk. This is not production-ready code — it should be reviewed, understood, and rewritten to suit your own environment before any real-world use.

This Terraform configuration uses a three-layer modular architecture to deploy a secure, globally distributed Azure web application infrastructure with **Azure Front Door Premium** and private App Services.

## 📁 Folder Structure

```
terraform/
├── environments/
│   └── dev/
│       ├── main.tf                    # Environment-specific configuration
│       ├── variables.tf               # Environment variables
│       ├── outputs.tf                 # Environment outputs
│       └── terraform.tfvars.example   # Example configuration
├── project/
│   ├── main.tf                        # Project-level orchestration
│   ├── variables.tf                   # Project variables
│   └── outputs.tf                     # Project outputs
└── modules/
    └── azurerm/
        ├── resource_group/            # Resource Group module
        ├── virtual_network/           # Virtual Network module
        ├── subnet/                    # Subnet module
        ├── private_dns/               # Private DNS Zone module
        ├── private_endpoint/          # Private Endpoint module
        ├── app_service/               # App Service module
        ├── front_door/                # Front Door module
        └── network_security_group/    # NSG module
```

## 🏗️ Architecture Overview

### Three-Layer Design

1. **Environments Layer** (`environments/dev/`)
   - Terraform and provider version constraints
   - Generates random suffix for resource uniqueness
   - Sets environment-specific configuration
   - Deploys multi-region infrastructure
   - Calls the project module for each region

2. **Project Layer** (`project/`)
   - Orchestrates all infrastructure components per region
   - Builds resource names following naming conventions
   - Calls individual resource modules
   - Manages dependencies between resources

3. **Modules Layer** (`modules/azurerm/`)
   - Reusable, single-purpose resource modules
   - Standardized inputs (name, resource_group_name, location, tags)
   - Consistent outputs (id, name, resource-specific outputs)

### Deployed Resources

**Per Region:**
- **Resource Group**: Container for regional resources
- **Virtual Network**: 10.0.0.0/16 (primary) and 10.1.0.0/16 (secondary) with two subnets
  - App Service Integration: 10.x.1.0/24
  - Private Endpoints: 10.x.2.0/24
- **App Service**: Linux-based, VNet integrated (completely private)
- **Private Endpoint**: Enables private connectivity to App Service
- **Network Security Group**: Controls traffic to App Service subnet

**Global:**
- **Azure Front Door Premium**: Global entry point with Private Link to regional App Services

## 🔒 Security Features

✅ **App Service is NOT publicly accessible** - Only through Azure Front Door Premium  
✅ **Private Link** - Front Door connects to App Services via Microsoft backbone network  
✅ **No certificate management required** - Front Door handles SSL/TLS with managed certificates  
✅ **VNet Integration** - App Service integrated into virtual network  
✅ **HTTPS enforced** - Automatic redirect and modern encryption  
✅ **WAF & DDoS Protection** - Built into Front Door Premium  
✅ **Multi-Region HA** - Automatic failover between regions  
✅ **Network Security Groups** - Traffic filtering at subnet level  

## 🚀 Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Active Azure subscription with appropriate permissions

### Deployment Steps

1. **Authenticate with Azure**

```bash
az login
az account set --subscription "<your-subscription-id>"
```

2. **Navigate to Environment Directory**

```bash
cd terraform/environments/dev
```

3. **Configure Variables**

Copy and customize the tfvars file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

**⚠️ IMPORTANT**: Edit `terraform.tfvars` and set secure credentials:


4. **Initialize Terraform**

```bash
terraform init
```

5. **Review the Deployment Plan**

```bash
terraform plan
```

6. **Deploy Infrastructure**

```bash
terraform apply
```

Type `yes` when prompted.

**Note**: Private Link connections are automatically approved via Terraform after a 30-second delay.

7. **Access Application**

After deployment (10-15 minutes), get the Front Door endpoint:

```bash
terraform output front_door_endpoint_url
```

Visit the URL shown (e.g., `https://afd-endpoint-7hn-xxx.azurefd.net`)

**Expected Result**: Default Azure App Service page saying "Your web app is running and waiting for your content."

## ⚙️ Configuration

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `environment_prefix` | Environment name | `dev` |
| `workload` | Workload identifier | `webapp` |
| `primary_location` | Primary Azure region | `eastus` |
| `secondary_location` | Secondary Azure region | `westus` |
| `data_location` | Data residency region | `""` (uses primary) |
| `vnet_address_space_primary` | Primary VNet CIDR | `10.0.0.0/16` |
| `vnet_address_space_secondary` | Secondary VNet CIDR | `10.1.0.0/16` |
| `app_service_sku` | App Service SKU | `B1` |

### Resource Naming Convention

Resources follow: `<type>-<workload>-<environment>-<region>-<suffix>`

**Examples with suffix "7hn":**

**Global Resources:**
- Global Resource Group: `rg-global-webapp-dev-7hn`
- Front Door Profile: `afd-webapp-dev-7hn`
- Front Door Endpoint: `afd-endpoint-7hn`

**Regional Resources (Primary - Central US):**
- Resource Group: `rg-webapp-dev-centralus-7hn`
- App Service: `app-webapp-dev-centralus-7hn`
- VNet: `vnet-webapp-dev-centralus-7hn`
- Private Endpoint: `pe-app-webapp-dev-centralus-7hn`

**Regional Resources (Secondary - Canada Central):**
- Resource Group: `rg-webapp-dev-canadacentral-7hn`
- App Service: `app-webapp-dev-canadacentral-7hn`
- VNet: `vnet-webapp-dev-canadacentral-7hn`
- Private Endpoint: `pe-app-webapp-dev-canadacentral-7hn`

## 📤 Outputs

After deployment, these outputs are available:

| Output | Description | Example |
|--------|-------------|---------||
| `front_door_endpoint_url` | Front Door HTTPS endpoint | `https://afd-endpoint-7hn-xxx.azurefd.net` |
| `primary_region` | Primary region name | `centralus` |
| `secondary_region` | Secondary region name | `canadacentral` |
| `primary_resource_group_name` | Primary RG name | `rg-webapp-dev-centralus-7hn` |
| `secondary_resource_group_name` | Secondary RG name | `rg-webapp-dev-canadacentral-7hn` |
| `primary_app_service_name` | Primary App Service | `app-webapp-dev-centralus-7hn` |
| `secondary_app_service_name` | Secondary App Service | `app-webapp-dev-canadacentral-7hn` |

View all outputs:

```bash
terraform output
```

Get specific output:

```bash
terraform output -raw front_door_endpoint_url
```

## 🌐 Network Architecture

```
                    Internet
                       │
                       ▼
        ┌──────────────────────────────┐
        │  Azure Front Door Premium    │
        │  - Global Anycast            │
        │  - WAF & DDoS Protection     │
        │  - Managed Certificates      │
        └──────┬──────────────┬────────┘
               │              │
      Private Link    Private Link
    (MS Backbone)   (MS Backbone)
               │              │
        ┌──────▼──────┐ ┌────▼────────┐
        │  Primary    │ │  Secondary  │
        │  Region     │ │  Region     │
        │             │ │             │
        │  App Service│ │  App Service│
        │  (Private)  │ │  (Private)  │
        │  10.0.1.0/24│ │  10.1.1.0/24│
        └─────────────┘ └─────────────┘
```


## 🔧 Module Usage

Each module follows a consistent pattern:

### Module Inputs
```hcl
module "example" {
  source = "../modules/azurerm/<resource>"
  
  name                = "resource-name"
  resource_group_name = "rg-name"
  location            = "eastus"
  tags                = { Environment = "dev" }
  
  # Resource-specific properties
}
```

### Module Outputs
```hcl
output "id" { value = azurerm_<resource>.main.id }
output "name" { value = azurerm_<resource>.main.name }
# Additional resource-specific outputs
```

## 🎯 Next Steps

1. **Deploy Application Code**
   - Use Azure CLI or CI/CD pipeline
   - Deploy to App Services in both regions

2. **Configure Custom Domain**
   - Add custom domain to Front Door
   - Azure manages SSL certificates automatically

3. **Set Up Monitoring**
   - Enable Application Insights
   - Configure Azure Monitor alerts
   - Review Front Door analytics

4. **Implement CI/CD**
   - GitHub Actions or Azure DevOps
   - Automated multi-region deployments

5. **Enhance Security**
   - Configure WAF policies on Front Door
   - Implement managed identities
   - Use Azure Key Vault for secrets

## 🧹 Cleanup

To destroy all resources:

```bash
cd terraform/environments/dev
terraform destroy
```

Type `yes` to confirm. This will remove all resources in both regions and the global Front Door.

## 🧪 Testing

### Test Primary Region Access

```bash
# Get endpoint URL
URL=$(terraform output -raw front_door_endpoint_url)

# Test access
curl -I $URL
# Expected: HTTP/2 200
```

### Test Failover Behavior

```bash
# Get resource names
PRIMARY_APP=$(terraform output -raw primary_app_service_name)
PRIMARY_RG=$(terraform output -raw primary_resource_group_name)

# Stop primary App Service
az webapp stop --name $PRIMARY_APP --resource-group $PRIMARY_RG

# Wait 2-3 minutes for health probes to fail
sleep 180

# Test - should route to secondary
curl -I $URL
# Expected: Still returns 200 (from secondary region)

# Restart primary
az webapp start --name $PRIMARY_APP --resource-group $PRIMARY_RG
```

### Verify Private Access Only

```bash
PRIMARY_APP=$(terraform output -raw primary_app_service_name)

# Try direct access (should fail)
curl -I https://$PRIMARY_APP.azurewebsites.net
# Expected: Connection refused or 403 Forbidden

# Access via Front Door (should succeed)
URL=$(terraform output -raw front_door_endpoint_url)
curl -I $URL
# Expected: HTTP/2 200
```

### Check Front Door Origin Health

```bash
# Get Front Door details
az afd origin list \
  --profile-name afd-webapp-dev-<suffix> \
  --origin-group-name afd-origin-group \
  --resource-group rg-global-webapp-dev-<suffix> \
  --query "[].{Name:name, HostName:hostName, Enabled:enabledState}" \
  --output table
```

## 🐛 Troubleshooting

### Common Issues

**504 Gateway Timeout after deployment**

**Cause**: Private Link connection from Front Door needs approval.

**Solution**: Terraform includes automatic approval, but if it fails:

```bash
# Check connection status
az network private-endpoint-connection list \
  --name app-webapp-dev-<region>-<suffix> \
  --resource-group rg-webapp-dev-<region>-<suffix> \
  --type Microsoft.Web/sites

# Approve if pending
az network private-endpoint-connection approve \
  --name <connection-name> \
  --resource-group rg-webapp-dev-<region>-<suffix> \
  --resource-name app-webapp-dev-<region>-<suffix> \
  --type Microsoft.Web/sites

# Wait 1-2 minutes and test again
```

**Front Door shows unhealthy origins**
- Check App Service is running: `az webapp show --name <app-name> --resource-group <rg-name> --query state`
- Verify Private Link is approved (see above)
- Review Front Door health probe configuration
- Check App Service logs: `az webapp log tail --name <app-name> --resource-group <rg-name>`

**Cannot access App Service directly (Expected)**

**This is correct behavior!** App Services have `public_network_access_enabled = false`.

✅ **Expected**: Front Door access works  
❌ **Expected**: Direct App Service access fails (403 Forbidden)

This confirms proper Private Link configuration.

**App Service health probe failing**
- Verify app is responding on root path `/`
- Default App Service page should return 200 OK
- Check App Service logs for errors
- Ensure HTTPS is enabled (it is by default)

**Terraform init fails**
- Verify Terraform version >= 1.0
- Check internet connectivity
- Clear `.terraform` directory and retry
- Run: `rm -rf .terraform .terraform.lock.hcl && terraform init`

**Deployment timeout**
- Front Door Premium provisioning: ~10-15 minutes (normal)
- Private Link auto-approval: ~30 seconds after origin creation
- Total deployment: ~15-20 minutes
- Monitor Azure Portal for detailed progress

**Multiple regions not failing over**
- Stop primary App Service to test: `az webapp stop --name <primary-app> --resource-group <primary-rg>`
- Wait 2-3 minutes for health probes to detect failure
- Traffic should automatically route to secondary
- Start primary: `az webapp start --name <primary-app> --resource-group <primary-rg>`
- Traffic returns to primary when healthy


## 📚 Additional Resources

- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Azure Front Door Documentation](https://docs.microsoft.com/azure/frontdoor/)
- [Azure Private Link Documentation](https://docs.microsoft.com/azure/private-link/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
