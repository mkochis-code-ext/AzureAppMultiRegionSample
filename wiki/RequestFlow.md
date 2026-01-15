# Request Flow: Multi-Region Architecture with Azure Front Door Premium

This document details the complete infrastructure deployment and network traffic flow from the public internet to Azure App Services across multiple regions.

## Architecture Deployment Overview

The infrastructure is deployed using a **three-layer Terraform architecture**:

### 1. Environment Layer (`environments/dev/`)
- Generates a unique random suffix for resource naming
- Creates a **global resource group** for Front Door (location: primary region)
- Deploys **two regional stacks** using the project module:
  - **Primary Region** (e.g., Central US)
  - **Secondary Region** (e.g., Canada Central)
- Configures **Front Door Premium** with both regions as origins

### 2. Project Layer (`project/`)
Each regional deployment creates:
- **Resource Group** (regional)
- **Virtual Network** with address space:
  - Primary: `10.0.0.0/16`
  - Secondary: `10.1.0.0/16`
- **Subnets**:
  - App Service Integration: `10.x.1.0/24`
  - Private Endpoints: `10.x.2.0/24`
- **App Service** (private, no public access)
- **Private Endpoint** for App Service
- **Private DNS Zone** (`privatelink.azurewebsites.net`)
- **Network Security Groups**

### 3. Modules Layer (`modules/azurerm/`)
Individual reusable modules for each resource type.

---

## Resource Naming Convention

Resources follow the pattern: `<type>-<workload>-<environment>-<region>-<suffix>`

**Example with suffix "7hn":**
- Global RG: `rg-global-webapp-dev-7hn`
- Primary App: `app-webapp-dev-centralus-7hn`
- Secondary App: `app-webapp-dev-canadacentral-7hn`
- Front Door: `afd-webapp-dev-7hn`
- Front Door Endpoint: `afd-endpoint-7hn`

---

## High-Level Traffic Flow

**Flow Summary:**
`User` → `Azure Front Door Premium (Global)` → `Private Link` → `App Service (Primary or Secondary Region)`

The system automatically routes to the primary region under normal conditions and fails over to the secondary region if the primary becomes unhealthy.

---

## Detailed Request Flow

### 1. Public Internet to Azure Front Door
*   **Source**: Public Internet client (browser, API client, mobile app).
*   **Destination**: Front Door endpoint (e.g., `https://afd-endpoint-7hn-xxx.azurefd.net`).
*   **Protocol/Port**: HTTP (80) redirects to HTTPS (443).
*   **Mechanism**:
    *   Front Door has a **global anycast IP address** that routes users to the nearest Microsoft edge location.
    *   **HTTPS Redirect**: HTTP requests are automatically redirected to HTTPS (301/302).
    *   **SSL/TLS Termination**: Front Door terminates the SSL connection using **Azure-managed certificates** (no certificate management required).
    *   **WAF & DDoS Protection**: Premium tier includes built-in Web Application Firewall and DDoS protection at the edge.

### 2. Azure Front Door Origin Selection
*   **Endpoint**: Front Door receives the request at its global endpoint.
*   **Origin Group**: `afd-origin-group` contains both regional origins.
*   **Health Probes**: 
    *   Sent every 100 seconds via HTTPS to each App Service default hostname
    *   Protocol: HTTPS
    *   Path: `/` (root)
    *   Request Type: HEAD
    *   Successful samples required: 3 out of 4
*   **Load Balancing Decision**:
    *   **Priority 1 (Primary Region)**: Weight 1000
    *   **Priority 2 (Secondary Region)**: Weight 1000
    *   Primary region is always preferred when healthy
    *   Automatic failover to secondary if primary is unhealthy

### 3. Private Link Connection (Critical Step)
*   **Context**: Front Door Premium supports Private Link to connect privately to Azure PaaS services.
*   **Mechanism**:
    *   Front Door initiates a connection through **Azure Private Link** (not over the public internet).
    *   Each origin has a dedicated Private Link connection to its regional App Service.
    *   **No Public Routing**: Traffic flows entirely on the **Microsoft backbone network** - never traverses the public internet.
    *   **Private Link Approval**: 
        *   Connections are initially "Pending" and require approval
        *   Terraform includes a `null_resource` that automatically approves connections after creation
        *   Approval command: `az network private-endpoint-connection approve`

### 4. Azure Front Door to App Service
*   **Source**: Azure Front Door (via Private Link from nearest Microsoft POP).
*   **Destination**: App Service Private Endpoint (in selected region).
*   **Protocol/Port**: HTTPS (443).
*   **Mechanism**:
    *   Traffic is encrypted and flows through Microsoft's private network backbone.
    *   **App Service Configuration**: 
        *   `public_network_access_enabled = false` - Rejects any traffic not from Private Endpoint
        *   `https_only = true` - Only accepts HTTPS connections
        *   `minimum_tls_version = "1.2"` - Enforces modern TLS
    *   **Host Header**: Front Door sends the App Service FQDN as the host header (e.g., `app-webapp-dev-centralus-7hn.azurewebsites.net`)
    *   **VNet Integration**: App Service is integrated into `snet-app-integration` for outbound connectivity

---

## Component Configuration Details

### Azure Front Door Premium
*   **Resource Group**: `rg-global-webapp-dev-<suffix>` (created in primary location)
*   **Profile**: `afd-webapp-dev-<suffix>`
*   **Endpoint**: `afd-endpoint-<suffix>.<hash>.azurefd.net`
*   **SKU**: `Premium_AzureFrontDoor` (required for Private Link support)
*   **Origin Group**: Single group with multiple regional origins
*   **Public Access**: Yes (global anycast endpoint)
*   **Backend Communication**: Private Link to each regional App Service
*   **Features**:
    *   Automatic HTTPS redirect (`https_redirect_enabled = true`)
    *   Azure-managed SSL certificates (auto-renewal)
    *   WAF and DDoS protection
    *   Global load balancing with health probes
    *   Multi-region automatic failover
    *   Session affinity support

### Regional Deployments (Primary & Secondary)

#### Resource Groups
- **Primary**: `rg-webapp-dev-<primary-region>-<suffix>`
- **Secondary**: `rg-webapp-dev-<secondary-region>-<suffix>`

#### Virtual Networks
- **Primary**: `vnet-webapp-dev-<primary-region>-<suffix>` (10.0.0.0/16)
- **Secondary**: `vnet-webapp-dev-<secondary-region>-<suffix>` (10.1.0.0/16)
- **Subnets** (per region):
  - `snet-app-integration`: For App Service VNet integration (10.x.1.0/24)
  - `snet-private-endpoints`: For Private Endpoints (10.x.2.0/24)

#### App Services
- **Primary**: `app-webapp-dev-<primary-region>-<suffix>`
- **Secondary**: `app-webapp-dev-<secondary-region>-<suffix>`
- **Configuration**:
  - OS: Linux
  - SKU: B1 (configurable)
  - Subnet Integration: `snet-app-integration` (for *outbound* traffic)
  - Public Access: **Disabled** (`public_network_access_enabled = false`)
  - Private Access: Enabled via Private Endpoint in `snet-private-endpoints`
  - HTTPS Only: Enabled
  - TLS Version: 1.2 minimum
  - VNet Route All: Enabled
  - System-Assigned Managed Identity: Enabled

#### Private Endpoints
- **Primary**: `pe-app-webapp-dev-<primary-region>-<suffix>`
- **Secondary**: `pe-app-webapp-dev-<secondary-region>-<suffix>`
- **Subnet**: `snet-private-endpoints` (10.x.2.0/24)
- **Subresource**: `sites` (App Service)
- **DNS Integration**: Links to Private DNS Zone

#### Private DNS
*   **Zone**: `privatelink.azurewebsites.net` (created per region)
*   **VNet Link**: Linked to the regional Virtual Network
*   **A Record**: Maps App Service name to Private Endpoint IP (10.x.2.4)
*   **Usage**: Enables VNet-internal name resolution; Front Door uses its own Private Link DNS resolution

#### Network Security Groups
*   **`nsg-app-<region>`**:
    *   Applied to `snet-app-integration`
    *   No specific inbound rules required (traffic controlled by Private Endpoint)
    *   Allows App Service to connect to Azure services for outbound traffic
    *   Applied per region

### Private Link Connections

Each Front Door origin creates a Private Link connection:
- **Primary**: Front Door → App Service (Primary Region)
- **Secondary**: Front Door → App Service (Secondary Region)

**Approval Process**:
1. Front Door creates connection (status: Pending)
2. Terraform `null_resource` waits 30 seconds
3. Auto-approves via Azure CLI: `az network private-endpoint-connection approve`
4. Connection status changes to "Approved"
5. Front Door health probes start succeeding

---

## Security Features

✅ **App Services are NOT publicly accessible** - Only through Azure Front Door Premium  
✅ **Private Link** - All traffic uses Microsoft backbone network, never public internet  
✅ **No certificate management** - Front Door handles SSL/TLS with Azure-managed certificates  
✅ **VNet Integration** - App Services integrated into virtual networks for outbound access  
✅ **HTTPS enforced** - Automatic redirect and TLS 1.2+ encryption  
✅ **WAF & DDoS Protection** - Built into Front Door Premium at the edge  
✅ **Multi-Region HA** - Automatic failover with health monitoring  
✅ **Zero public endpoints** - All App Services completely private  
✅ **Network isolation** - Separate VNets per region with no peering required  
✅ **Least privilege** - NSGs with minimal rules, Private Endpoints control access

---

---

## Traffic Flow Diagrams

### Multi-Region Architecture

```
                           ┌─────────────────┐
                           │  Internet Users │
                           └────────┬────────┘
                                    │ HTTPS (443)
                                    │ HTTP → HTTPS Redirect
                                    ▼
                    ┌───────────────────────────────┐
                    │  Azure Front Door Premium     │
                    │  (Global - Anycast IP)        │
                    │  ┌─────────────────────────┐  │
                    │  │ • WAF & DDoS Protection │  │
                    │  │ • SSL/TLS Termination   │  │
                    │  │ • Health Monitoring     │  │
                    │  │ • Managed Certificates  │  │
                    │  └─────────────────────────┘  │
                    └────────┬──────────────┬───────┘
                             │              │
                   Priority 1│              │Priority 2
                   (Primary) │              │(Failover)
                             │              │
                    Private Link       Private Link
                  (MS Backbone)      (MS Backbone)
                             │              │
         ┌───────────────────▼──────┐   ┌──▼──────────────────┐
         │   PRIMARY REGION         │   │  SECONDARY REGION   │
         │   (e.g., Central US)     │   │  (e.g., Canada C.)  │
         │                          │   │                     │
         │  ┌────────────────────┐  │   │  ┌───────────────┐  │
         │  │  App Service       │  │   │  │  App Service  │  │
         │  │  (Private)         │  │   │  │  (Private)    │  │
         │  │  10.0.1.0/24       │  │   │  │  10.1.1.0/24  │  │
         │  └─────────▲──────────┘  │   │  └────▲──────────┘  │
         │            │             │   │       │             │
         │  ┌─────────┴──────────┐  │   │  ┌────┴─────────┐   │
         │  │  Private Endpoint  │  │   │  │  Private EP  │   │
         │  │  10.0.2.0/24       │  │   │  │  10.1.2.0/24 │   │
         │  └────────────────────┘  │   │  └──────────────┘   │
         │                          │   │                     │
         │  VNet: 10.0.0.0/16       │   │  VNet: 10.1.0.0/16  │
         └──────────────────────────┘   └────────────────────┘
```

### Request Flow Sequence

```
┌──────┐         ┌─────────┐         ┌────────────┐         ┌────────────┐
│Client│         │ Front   │         │  Private   │         │    App     │
│      │         │  Door   │         │    Link    │         │  Service   │
└──┬───┘         └────┬────┘         └─────┬──────┘         └─────┬──────┘
   │                  │                    │                      │
   │  HTTP Request    │                    │                      │
   │─────────────────>│                    │                      │
   │                  │                    │                      │
   │  301/302 Redirect│                    │                      │
   │<─────────────────│                    │                      │
   │                  │                    │                      │
   │  HTTPS Request   │                    │                      │
   │─────────────────>│                    │                      │
   │                  │                    │                      │
   │                  │  Health Check      │                      │
   │                  │───────────────────>│                      │
   │                  │                    │  HTTPS HEAD /        │
   │                  │                    │─────────────────────>│
   │                  │                    │  200 OK              │
   │                  │                    │<─────────────────────│
   │                  │  Healthy           │                      │
   │                  │<───────────────────│                      │
   │                  │                    │                      │
   │                  │  Route to Primary  │                      │
   │                  │  (Priority 1)      │                      │
   │                  │                    │                      │
   │                  │  Private Link HTTPS│                      │
   │                  │───────────────────>│                      │
   │                  │                    │  HTTPS GET /         │
   │                  │                    │─────────────────────>│
   │                  │                    │                      │
   │                  │                    │  Response            │
   │                  │                    │<─────────────────────│
   │                  │  Response          │                      │
   │                  │<───────────────────│                      │
   │  Response        │                    │                      │
   │<─────────────────│                    │                      │
   │                  │                    │                      │
```

### Failover Scenario

```
Primary Region Health Check: FAILED ❌
        │
        ▼
Front Door detects unhealthy origin
        │
        ▼
Removes Primary from rotation
        │
        ▼
Routes traffic to Secondary Region (Priority 2) ✅
        │
        ▼
All requests go to Secondary until Primary recovers
        │
        ▼
Primary Health Check: SUCCESS ✅
        │
        ▼
Front Door adds Primary back to rotation
        │
        ▼
Traffic returns to Primary (Priority 1)
```

---

## Deployment Flow

### Terraform Apply Sequence

1. **Random Suffix Generation**
   - Creates 3-character suffix (e.g., "7hn")
   - Used across all resources for uniqueness

2. **Global Resource Group**
   - `rg-global-webapp-dev-<suffix>`
   - Located in primary region (organizational requirement)

3. **Primary Region Deployment** (Parallel)
   - Resource Group
   - Virtual Network (10.0.0.0/16)
   - Subnets (app integration, private endpoints)
   - App Service Plan & App Service
   - Private DNS Zone
   - Private Endpoint
   - Network Security Groups

4. **Secondary Region Deployment** (Parallel)
   - Resource Group
   - Virtual Network (10.1.0.0/16)
   - Subnets (app integration, private endpoints)
   - App Service Plan & App Service
   - Private DNS Zone
   - Private Endpoint
   - Network Security Groups

5. **Front Door Configuration**
   - Front Door Profile (Premium SKU)
   - Front Door Endpoint
   - Origin Group
   - Origins (Primary + Secondary with Private Link)
   - Route Configuration

6. **Private Link Approval** (Auto)
   - `null_resource` waits 30 seconds
   - Discovers pending Private Link connections
   - Auto-approves via Azure CLI
   - Health probes start succeeding

**Total Deployment Time**: ~10-15 minutes

---

## Testing and Validation

### 1. Verify Deployment
```powershell
# Get Front Door endpoint
terraform output front_door_endpoint_url

# Check Private Link status (Primary)
az network private-endpoint-connection list \
  --name app-webapp-dev-centralus-<suffix> \
  --resource-group rg-webapp-dev-centralus-<suffix> \
  --type Microsoft.Web/sites

# Check Front Door origins
az afd origin list \
  --profile-name afd-webapp-dev-<suffix> \
  --origin-group-name afd-origin-group \
  --resource-group rg-global-webapp-dev-<suffix>
```

### 2. Test Primary Region
```powershell
# Access Front Door endpoint
Invoke-WebRequest -Uri "https://afd-endpoint-<suffix>-<hash>.azurefd.net"

# Should return 200 OK from primary region
```

### 3. Test Failover
```powershell
# Stop primary App Service
az webapp stop --name app-webapp-dev-centralus-<suffix> \
  --resource-group rg-webapp-dev-centralus-<suffix>

# Wait for health probe to fail (~2-3 minutes)
# Test endpoint - should route to secondary
Invoke-WebRequest -Uri "https://afd-endpoint-<suffix>-<hash>.azurefd.net"

# Start primary App Service
az webapp start --name app-webapp-dev-centralus-<suffix> \
  --resource-group rg-webapp-dev-centralus-<suffix>

# Traffic returns to primary after health check succeeds
```

### 4. Verify Private Access
```powershell
# Try to access App Service directly (should fail)
Invoke-WebRequest -Uri "https://app-webapp-dev-centralus-<suffix>.azurewebsites.net"
# Expected: Connection refused or 403 Forbidden

# Access via Front Door (should succeed)
Invoke-WebRequest -Uri "https://afd-endpoint-<suffix>-<hash>.azurefd.net"
# Expected: 200 OK
```

---

## Operational Considerations

### Monitoring
- **Front Door Metrics**: Requests, latency, origin health
- **App Service Metrics**: CPU, memory, response time
- **Private Link Metrics**: Connection status, data transferred
- **Health Probe Status**: Monitor in Azure Portal → Front Door → Origin Groups

### Scaling
- **Horizontal**: Increase App Service Plan instances per region
- **Vertical**: Change App Service SKU (B1 → P1v2, etc.)
- **Geographic**: Add more regional deployments to Front Door origins

### Cost Optimization
- Use B-series SKU for dev/test environments
- Use P-series for production workloads
- Front Door Premium pricing: Per zone + data transfer
- Private Link: Per connection + data processed

### Disaster Recovery
- **RTO**: ~2-3 minutes (health probe interval)
- **RPO**: Real-time (both regions serve live traffic)
- **Automatic Failover**: No manual intervention required
- **Regional Outage**: Front Door automatically routes to healthy region

---

## Troubleshooting Guide

### Issue: 504 Gateway Timeout

**Possible Causes**:
1. Private Link connection not approved
2. App Service not running
3. Health probe failing

**Resolution**:
```powershell
# Check Private Link status
az network private-endpoint-connection list \
  --name <app-service-name> \
  --resource-group <resource-group> \
  --type Microsoft.Web/sites

# Approve if pending
az network private-endpoint-connection approve \
  --name <connection-name> \
  --resource-group <resource-group> \
  --resource-name <app-service-name> \
  --type Microsoft.Web/sites

# Check App Service status
az webapp show --name <app-service-name> \
  --resource-group <resource-group> \
  --query state
```

### Issue: Front Door shows unhealthy origins

**Possible Causes**:
1. App Service stopped or failing
2. Private Link connection not established
3. App Service not responding on health probe path

**Resolution**:
```powershell
# Check App Service logs
az webapp log tail --name <app-service-name> \
  --resource-group <resource-group>

# Restart App Service
az webapp restart --name <app-service-name> \
  --resource-group <resource-group>

# Check Front Door health probe configuration
az afd origin-group show \
  --profile-name <front-door-name> \
  --origin-group-name afd-origin-group \
  --resource-group <resource-group>
```

### Issue: Cannot access via Front Door but App Service works directly

**This is expected behavior!** App Services have `public_network_access_enabled = false`.

**Verification**:
- Front Door access should work
- Direct App Service access should fail (403 Forbidden)
- This confirms proper Private Link configuration

---

## Additional Resources

- [Azure Front Door Documentation](https://docs.microsoft.com/azure/frontdoor/)
- [Private Link Service Documentation](https://docs.microsoft.com/azure/private-link/)
- [App Service Private Endpoint](https://docs.microsoft.com/azure/app-service/networking/private-endpoint)
- [Front Door Origin Load Balancing](https://docs.microsoft.com/azure/frontdoor/front-door-traffic-acceleration)
