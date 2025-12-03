// ============================================================================
// Role Assignments Module - RBAC Permissions
// ============================================================================
// Description: Assigns RBAC roles to the VM managed identity
// ============================================================================

@description('Principal ID of the VM managed identity')
param principalId string

@description('Storage account name')
param storageAccountName string

@description('Key Vault name')
param keyVaultName string

// ============================================================================
// Built-in Role Definitions
// ============================================================================

// Storage Blob Data Contributor - allows read/write blob data
var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

// Key Vault Secrets User - allows reading secrets
var keyVaultSecretsUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

// ============================================================================
// Storage Account Reference
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// ============================================================================
// Key Vault Reference
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// ============================================================================
// Role Assignments
// ============================================================================

// Grant Storage Blob Data Contributor to VM identity for reading/writing billing exports and backups
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, principalId, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant Key Vault Secrets User to VM identity for reading secrets and certificates
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The role assignment ID for storage access')
output storageRoleAssignmentId string = storageRoleAssignment.id

@description('The role assignment ID for Key Vault access')
output keyVaultRoleAssignmentId string = keyVaultRoleAssignment.id
