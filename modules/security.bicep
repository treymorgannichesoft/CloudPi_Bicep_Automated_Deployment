// ============================================================================
// Security Module - Azure Key Vault
// ============================================================================
// Description: Creates Key Vault for secrets and certificates
// ============================================================================

@description('Azure region for resources')
param location string

@description('Environment name')
param environment string

@description('Resource tags')
param tags object

@description('Project name for resource naming')
param namingPrefix string

@description('Azure AD Tenant ID')
param tenantId string

// ============================================================================
// Variables
// ============================================================================

// Generate a deterministic unique suffix based on subscription, project, and environment
// This ensures the same name for the same environment, but avoids conflicts with soft-deleted vaults
var uniqueSuffix = take(uniqueString(subscription().subscriptionId, namingPrefix, environment), 6)
var keyVaultName = 'kv-${namingPrefix}-${environment}-${uniqueSuffix}'

// ============================================================================
// Key Vault
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true // Use RBAC instead of access policies
    enablePurgeProtection: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow' // Can be changed to 'Deny' with private endpoints
    }
    publicNetworkAccess: 'Enabled' // Can be disabled with private endpoints
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The name of the Key Vault')
output keyVaultName string = keyVault.name

@description('The resource ID of the Key Vault')
output keyVaultId string = keyVault.id

@description('The URI of the Key Vault')
output keyVaultUri string = keyVault.properties.vaultUri
