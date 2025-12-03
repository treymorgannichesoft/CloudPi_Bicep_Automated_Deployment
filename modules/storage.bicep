// ============================================================================
// Storage Module - Storage Account
// ============================================================================
// Description: Creates storage account for billing exports and app data
// ============================================================================

@description('Azure region for resources')
param location string

@description('Resource tags')
param tags object

@description('Naming prefix for resources')
param namingPrefix string

// ============================================================================
// Variables
// ============================================================================

// Storage account names must be lowercase and alphanumeric only (no hyphens)
// Max 24 characters
var storageAccountName = replace('st${namingPrefix}apps', '-', '')

// ============================================================================
// Storage Account
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow' // Can be changed to 'Deny' with private endpoints in production
    }
    accessTier: 'Hot'
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// ============================================================================
// Blob Service (for lifecycle policies and containers)
// ============================================================================

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// ============================================================================
// Blob Containers
// ============================================================================

resource billingExportsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'billing-exports'
  properties: {
    publicAccess: 'None'
  }
}

resource backupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'mysql-backups'
  properties: {
    publicAccess: 'None'
  }
}

resource appDataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'app-data'
  properties: {
    publicAccess: 'None'
  }
}

// ============================================================================
// Lifecycle Management Policy
// ============================================================================

resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'expire-old-mysql-backups'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                'mysql-backups/'
              ]
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 30
                }
                delete: {
                  daysAfterModificationGreaterThan: 90
                }
              }
            }
          }
        }
        {
          enabled: true
          name: 'expire-old-billing-exports'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                'billing-exports/'
              ]
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 90
                }
                delete: {
                  daysAfterModificationGreaterThan: 365
                }
              }
            }
          }
        }
      ]
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The name of the storage account')
output storageAccountName string = storageAccount.name

@description('The resource ID of the storage account')
output storageAccountId string = storageAccount.id

@description('The primary endpoints for the storage account')
output storageAccountPrimaryEndpoints object = storageAccount.properties.primaryEndpoints

@description('The name of the billing exports container')
output billingExportsContainerName string = billingExportsContainer.name

@description('The name of the MySQL backups container')
output backupsContainerName string = backupsContainer.name

@description('The name of the app data container')
output appDataContainerName string = appDataContainer.name
