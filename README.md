# CloudPi Azure Infrastructure

Infrastructure as Code for deploying CloudPi production environment on Azure using Bicep templates.

## Overview

This repository contains modular Bicep templates to deploy a complete production-ready infrastructure for the CloudPi application, including networking, compute, storage, security, and monitoring components.

## Quick Start

```bash
# Login to Azure
az login

# Run interactive deployment
./deploy-interactive.sh
```

The interactive script will:
- Auto-detect your Azure subscription and tenant
- Guide you through project naming and environment selection (dev/test/prod)
- Configure network settings and deployment options
- Deploy in ~10-15 minutes

For detailed instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Project Structure

```
CloudPi_01/
├── main.bicep                    # Main orchestration template
├── main.bicepparam               # Default parameter file
├── parameters.json               # Production parameters
├── test.parameters.json          # Test environment parameters
├── dev.parameters.json           # Dev environment parameters
├── deploy-interactive.sh         # Interactive deployment script
├── DEPLOYMENT.md                 # Comprehensive deployment guide
├── README.md                     # This file
└── modules/
    ├── networking.bicep          # VNet, subnets, NSG
    ├── storage.bicep             # Storage account and containers
    ├── security.bicep            # Key Vault
    ├── compute.bicep             # VM with Docker and monitoring
    ├── monitoring.bicep          # Log Analytics, alerts, backup
    └── roleAssignments.bicep     # RBAC permissions
```

## What Gets Deployed

### Infrastructure Components

| Category | Resources | Purpose |
|----------|-----------|---------|
| **Management** | Resource Group | Container for all resources |
| **Networking** | VNet, Subnet, NSG | Network isolation with auto-assigned IP ranges |
| **Compute** | Ubuntu 22.04 VM | Application server with Docker pre-installed |
| **Storage** | Storage Account | Billing exports, MySQL backups, app data |
| **Security** | Key Vault, Managed Identity | Secrets management and passwordless auth |
| **Monitoring** | Log Analytics, Alerts | Centralized logging and performance metrics |
| **Backup** | Recovery Services Vault | Daily VM backups (configurable) |

**Total**: 13+ Azure resources per environment

### Multi-Environment Support

**Automatic IP range assignment** prevents conflicts when deploying multiple projects:
- IP ranges are **auto-generated** from `projectName + environment` hash
- Each unique combination gets a **deterministic, conflict-free** IP range
- Range: `10.50-249.x.x/16` (200 possible unique networks)
- **Manual override** supported for enterprise IP planning

| Environment | VM Size | Data Disk | Backup | IP Assignment | Est. Monthly |
|-------------|---------|-----------|--------|---------------|--------------|
| **dev** | D2s_v3 | 128GB | No | Auto (10.x.0.0/16) | ~$90-120 |
| **test** | D2s_v3 | 256GB | 14-day | Auto (10.y.0.0/16) | ~$130-160 |
| **prod** | D4s_v3 | 256GB | 30-day | Auto (10.z.0.0/16) | ~$190-220 |

> **Example:** `cloudpi-dev` and `myapp-dev` get different IP ranges automatically

See [DEPLOYMENT.md](DEPLOYMENT.md#network-strategy-details) for detailed network information.

## Key Features

- **Flexible Naming**: Parameterized project naming for multi-tenant/multi-project deployments
- **Auto-Detection**: Automatically detects Azure subscription and tenant context
- **Zero-Trust Security**: No public IPs by default, NSG-based access control
- **Managed Identity**: Passwordless authentication to Azure services
- **Automated Monitoring**: Performance metrics and syslog collection via Azure Monitor
- **Automated Backups**: Daily VM backups with configurable retention
- **Docker Ready**: VM pre-configured with Docker and Docker Compose
- **Cost Optimization**: Lifecycle policies for automatic data archival
- **Multi-Environment**: Isolated dev, test, prod with automatic IP assignment

## Prerequisites

- **Azure CLI** 2.50.0 or later
- **Bicep CLI** 0.20.0 or later
- **SSH key pair** for VM access
- **Azure permissions**: Owner or Contributor role on subscription

## Deployment Options

### Option 1: Interactive Deployment (Recommended)

```bash
./deploy-interactive.sh
```

Guides you through:
- Azure subscription verification (auto-detected)
- Project name for resource naming
- Environment selection (dev/test/prod)
- Public IP option for testing
- Azure region selection
- Deployment summary with cost estimates

### Option 2: Direct Deployment with Parameter Files

```bash
# Deploy production
az deployment sub create \
  --name cloudpi-prod-$(date +%Y%m%d-%H%M%S) \
  --location eastus2 \
  --template-file main.bicep \
  --parameters @parameters.json

# Deploy test
az deployment sub create \
  --name cloudpi-test-$(date +%Y%m%d-%H%M%S) \
  --location eastus2 \
  --template-file main.bicep \
  --parameters @test.parameters.json

# Deploy dev
az deployment sub create \
  --name cloudpi-dev-$(date +%Y%m%d-%H%M%S) \
  --location eastus2 \
  --template-file main.bicep \
  --parameters @dev.parameters.json
```

### Option 3: Preview Before Deployment

```bash
# Use --what-if to preview changes
az deployment sub create \
  --location eastus2 \
  --template-file main.bicep \
  --parameters @parameters.json \
  --what-if
```

## Architecture Highlights

### Networking
- Hub-spoke topology ready (peering not included)
- Automatic non-overlapping IP ranges per environment
- NSG with least-privilege access rules
- Service tags for Azure service connectivity

### Security
- RBAC-based access control
- System-assigned managed identity
- Soft-delete and purge protection on Key Vault
- Encrypted storage and disks
- No public IPs by default

### High Availability & DR
- Daily automated backups (configurable)
- Premium SSD for performance
- Lifecycle policies for cost optimization
- Data disk auto-mounted at `/mnt/cloudpi-data`

### Monitoring
- Azure Monitor Agent for metrics and logs
- Performance counters: CPU, memory, disk
- Syslog collection for system events
- Email alerts for critical issues
- Log Analytics workspace with data collection rules

## Post-Deployment Tasks

After successful deployment:

1. **Connect to VM** - Use private IP, Bastion, or optional public IP for testing
2. **Verify Docker** - Docker and Docker Compose pre-installed via cloud-init
3. **Configure Cost Export** - Set up Azure Cost Management export to storage
4. **Deploy Application** - Deploy your application using Docker Compose
5. **(Optional) Store Secrets in Key Vault** - Use Key Vault for sensitive configuration
6. **Configure Backups** - Set up backup scripts as needed
7. **Test Monitoring** - Verify metrics and logs in Log Analytics

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed post-deployment steps.

## Deployment Outputs

After deployment, retrieve important information:

```bash
# Set deployment name
DEPLOYMENT_NAME="cloudpi-prod-20251116-120000"

# Get outputs
az deployment sub show --name $DEPLOYMENT_NAME --query properties.outputs

# Specific values
RG_NAME=$(az deployment sub show --name $DEPLOYMENT_NAME --query properties.outputs.resourceGroupName.value -o tsv)
VM_IP=$(az deployment sub show --name $DEPLOYMENT_NAME --query properties.outputs.vmPrivateIpAddress.value -o tsv)
STORAGE=$(az deployment sub show --name $DEPLOYMENT_NAME --query properties.outputs.storageAccountName.value -o tsv)
KV_URI=$(az deployment sub show --name $DEPLOYMENT_NAME --query properties.outputs.keyVaultUri.value -o tsv)
```

## Customization

### Extending the Infrastructure

The modular design allows easy customization:

- **Add Application Gateway** - Uncomment AGW subnet in networking module
- **Enable Private Endpoints** - Update storage and Key Vault modules
- **Add VNet Peering** - Connect to hub VNet for central connectivity
- **Multi-VM Deployment** - Extend compute module with VM scale set
- **Managed Database** - Replace VM MySQL with Azure Database for MySQL

### Custom Environment

Create your own parameter file:

```bash
cp parameters.json my-environment.parameters.json
# Edit with your values
nano my-environment.parameters.json

# Deploy
az deployment sub create \
  --name cloudpi-custom-$(date +%Y%m%d-%H%M%S) \
  --location eastus2 \
  --template-file main.bicep \
  --parameters @my-environment.parameters.json
```

## Troubleshooting

Common issues and solutions are documented in [DEPLOYMENT.md](DEPLOYMENT.md#troubleshooting).

Quick checks:

```bash
# Verify tools
az --version
az bicep version

# Validate template
az bicep build --file main.bicep

# Check deployment status
az deployment sub show --name cloudpi-prod-20251116-120000

# View activity logs
az monitor activity-log list --resource-group rg-cloudpi-prod
```

## Maintenance

### Regular Tasks
- **Monthly**: Review and update NSG rules
- **Quarterly**: Review backup retention and test restores
- **As needed**: Update VM size based on performance metrics
- **As needed**: Rotate secrets in Key Vault

### Cost Optimization
- Monitor unused resources via Azure Advisor
- Review storage lifecycle policies
- Use Azure Cost Management exports (configured post-deployment)
- Deallocate VMs when not in use (dev/test)

## Security Best Practices

This template implements:

- ✅ No public IPs on VMs (optional for testing)
- ✅ NSG with explicit allow rules only
- ✅ Managed identity instead of credentials
- ✅ RBAC-based access control
- ✅ Encryption at rest for all storage
- ✅ TLS 1.2 minimum for all services
- ✅ Soft-delete enabled on Key Vault
- ✅ Boot diagnostics enabled
- ✅ Automated patching configured

## Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment guide with troubleshooting and network strategy

## Clean Up

To delete all resources:

```bash
# Delete environment
az group delete --name rg-cloudpi-{env} --yes --no-wait

# Purge Key Vault (if needed)
az keyvault purge --name kv-cloudpi-{env}
```

## Resources

- [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/)
- [Azure Monitor for VMs](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/vminsights-overview)
- [Azure Backup](https://learn.microsoft.com/en-us/azure/backup/backup-azure-vms-introduction)

## Support

For questions or issues:
- Review [DEPLOYMENT.md](DEPLOYMENT.md) troubleshooting section
- Check Azure activity logs in portal
- Contact: trey.morgan@nichesoft.ai

---

**Ready to deploy?** Run `./deploy-interactive.sh` to get started!
