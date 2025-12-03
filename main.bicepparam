// ============================================================================
// CloudPi Production Infrastructure - Parameters File
// ============================================================================
// Description: Parameter values for deploying CloudPi infrastructure
// Instructions: Update the values below with your specific configuration
// ============================================================================

using './main.bicep'

// ============================================================================
// Environment Configuration
// ============================================================================

param projectName = 'cloudpi'  // Project name for resource naming (3-10 characters)
param environment = 'test'  // Changed to 'test' for initial deployment
param location = 'eastus'

// ============================================================================
// Tags
// ============================================================================

param tags = {
  Application: 'CloudPi'
  Environment: 'Test'
  ManagedBy: 'Bicep'
  CostCenter: 'FinOps'
  Owner: 'Trey Morgan - NicheSoft'
}

// ============================================================================
// Networking Configuration
// ============================================================================

param vnetAddressPrefix = ''  // Auto-assigned based on projectName + environment
param appSubnetPrefix = ''    // Auto-assigned based on projectName + environment

// Network access set to VirtualNetwork for testing
// For production, replace with specific IP ranges:
// - Netskope connector IPs: ['10.x.x.x/24', '10.y.y.y/24']
// - Corporate network: ['172.16.0.0/16']
// - VPN gateway: ['10.100.1.0/24']
param sshAllowedSourceAddresses = [
  'VirtualNetwork'  // Allows SSH from within Azure VNet
]

param httpsAllowedSourceAddresses = [
  'VirtualNetwork'  // Allows HTTPS from within Azure VNet
]

// ============================================================================
// Compute Configuration
// ============================================================================

param vmSize = 'Standard_D4s_v5'
param adminUsername = 'azureadmin'

// SSH public key - Generate with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/cloudpi_azure
// Then copy the content of ~/.ssh/cloudpi_azure.pub here
// Or use the interactive script which auto-generates keys
param sshPublicKey = 'YOUR_SSH_PUBLIC_KEY_HERE'

param osDiskSizeGB = 128
param dataDiskSizeGB = 256

// ============================================================================
// Backup Configuration
// ============================================================================

param enableBackup = true
param backupRetentionDays = 30

// ============================================================================
// Auto-Shutdown Configuration (recommended for dev/test)
// ============================================================================

param enableAutoShutdown = true  // Set to true for dev/test, false for prod
param autoShutdownTime = '2200'  // 10 PM in 24-hour format
param autoShutdownTimeZone = 'Eastern Standard Time'  // EST, CST, PST, UTC
param autoShutdownNotificationEmail = ''  // Optional email for shutdown notifications

// ============================================================================
// Monitoring Configuration
// ============================================================================

// Email addresses for alert notifications
param alertEmailAddresses = [
  'your-email@example.com'
]

// ============================================================================
// Identity Configuration
// ============================================================================

// Azure AD Tenant ID - Get with: az account show --query tenantId -o tsv
// Or use the interactive script which auto-detects it
param tenantId = 'YOUR_TENANT_ID_HERE'
