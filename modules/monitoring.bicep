// ============================================================================
// Monitoring Module - Log Analytics, Alerts, and Backup
// ============================================================================
// Description: Creates monitoring and backup infrastructure
// ============================================================================

@description('Azure region for resources')
param location string

@description('Environment name')
param environment string

@description('Resource tags')
param tags object

@description('Project name for resource naming')
param namingPrefix string

@description('Email addresses for alert notifications')
param alertEmailAddresses array

@description('Enable Azure Backup')
param enableBackup bool

@description('Backup retention in days')
param backupRetentionDays int

// ============================================================================
// Variables
// ============================================================================

var logAnalyticsWorkspaceName = 'law-${namingPrefix}-${environment}'
var actionGroupName = 'ag-${namingPrefix}-${environment}'
var recoveryServicesVaultName = 'rsv-${namingPrefix}-${environment}'

// ============================================================================
// Log Analytics Workspace
// ============================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1 // Set a daily cap to control costs
    }
  }
}

// ============================================================================
// Action Group for Alerts
// ============================================================================

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if (!empty(alertEmailAddresses)) {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: take('${namingPrefix}-${environment}', 12)
    enabled: true
    emailReceivers: [for (email, i) in alertEmailAddresses: {
      name: 'email-${i}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
  }
}

// ============================================================================
// Metric Alerts (will be configured after VM deployment)
// ============================================================================

// Note: VM-specific alerts will be created in the compute module or after deployment
// This includes CPU, memory, disk usage alerts

// ============================================================================
// Recovery Services Vault (for Azure Backup)
// ============================================================================

resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2024-01-01' = if (enableBackup) {
  name: recoveryServicesVaultName
  location: location
  tags: tags
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

// ============================================================================
// Backup Policy for VMs
// ============================================================================

resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2024-01-01' = if (enableBackup) {
  parent: recoveryServicesVault
  name: 'DailyBackupPolicy'
  properties: {
    backupManagementType: 'AzureIaasVM'
    instantRpRetentionRangeInDays: 2
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '2024-01-01T02:00:00Z' // 2 AM UTC
      ]
      scheduleWeeklyFrequency: 0
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2024-01-01T02:00:00Z'
        ]
        retentionDuration: {
          count: backupRetentionDays
          durationType: 'Days'
        }
      }
    }
    timeZone: 'UTC'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The resource ID of the Log Analytics workspace')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics workspace')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

@description('The workspace ID (customer ID) for agents')
output logAnalyticsWorkspaceCustomerId string = logAnalyticsWorkspace.properties.customerId

@description('The resource ID of the action group')
output actionGroupId string = !empty(alertEmailAddresses) ? actionGroup.id : ''

@description('The name of the action group')
output actionGroupName string = !empty(alertEmailAddresses) ? actionGroup.name : ''

@description('The name of the Recovery Services Vault')
output recoveryServicesVaultName string = enableBackup ? recoveryServicesVault.name : ''

@description('The resource ID of the Recovery Services Vault')
output recoveryServicesVaultId string = enableBackup ? recoveryServicesVault.id : ''

@description('The name of the backup policy')
output backupPolicyName string = enableBackup ? backupPolicy.name : ''
