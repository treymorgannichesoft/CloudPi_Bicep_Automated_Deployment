// ============================================================================
// Compute Module - Virtual Machine with Docker
// ============================================================================
// Description: Creates VM with managed identity and monitoring extensions
// ============================================================================

@description('Azure region for resources')
param location string

@description('Environment name')
param environment string

@description('Resource tags')
param tags object

@description('Project name for resource naming')
param namingPrefix string

@description('VM size')
param vmSize string

@description('Admin username')
param adminUsername string

@description('SSH public key')
@secure()
param sshPublicKey string

@description('OS disk size in GB')
param osDiskSizeGB int

@description('Data disk size in GB')
param dataDiskSizeGB int

@description('Subnet resource ID for the VM')
param subnetId string

@description('NSG resource ID')
param nsgId string

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Recovery Services Vault name (if backup is enabled)')
param recoveryServicesVaultName string

@description('Enable backup')
param enableBackup bool

@description('Enable auto-shutdown schedule')
param enableAutoShutdown bool = false

@description('Auto-shutdown time in 24-hour format (e.g., 2200 for 10 PM)')
param autoShutdownTime string = '2200'

@description('Timezone for auto-shutdown (e.g., Eastern Standard Time, Pacific Standard Time)')
param autoShutdownTimeZone string = 'UTC'

@description('Email notification for auto-shutdown')
param autoShutdownNotificationEmail string = ''

// ============================================================================
// Variables
// ============================================================================

var vmName = 'vm-${namingPrefix}-app-01-${environment}'
var nicName = 'nic-${namingPrefix}-app-01-${environment}'
var osDiskName = '${vmName}-osdisk'
var dataDiskName = '${vmName}-datadisk'

// Cloud-init configuration for Docker setup
var cloudInit = base64('''
#cloud-config
package_upgrade: true
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release

write_files:
  - path: /etc/docker/daemon.json
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "10m",
          "max-file": "3"
        }
      }

runcmd:
  # Install Docker
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ${adminUsername}

  # Create data disk mount point
  - mkdir -p /mnt/cloudpi-data

  # Format and mount data disk (assuming it's /dev/sdc)
  - |
    if [ -b /dev/sdc ]; then
      parted /dev/sdc --script mklabel gpt mkpart primary ext4 0% 100%
      mkfs.ext4 /dev/sdc1
      echo '/dev/sdc1 /mnt/cloudpi-data ext4 defaults,nofail 0 2' >> /etc/fstab
      mount -a
      chown -R ${adminUsername}:${adminUsername} /mnt/cloudpi-data
    fi

  # Create directories for CloudPi
  - mkdir -p /mnt/cloudpi-data/mysql
  - mkdir -p /mnt/cloudpi-data/app
  - mkdir -p /mnt/cloudpi-data/logs
  - mkdir -p /mnt/cloudpi-data/backups
  - chown -R ${adminUsername}:${adminUsername} /mnt/cloudpi-data

  # Install Azure CLI (for potential management tasks)
  - curl -sL https://aka.ms/InstallAzureCLIDeb | bash
''')

// ============================================================================
// Network Interface
// ============================================================================

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgId
    }
  }
}

// ============================================================================
// Virtual Machine
// ============================================================================

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      customData: cloudInit
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'IfRequired'
          }
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: osDiskSizeGB
        deleteOption: 'Delete'
      }
      dataDisks: [
        {
          name: dataDiskName
          lun: 0
          createOption: 'Empty'
          diskSizeGB: dataDiskSizeGB
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
          deleteOption: 'Delete'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// ============================================================================
// VM Extensions
// ============================================================================

// Azure Monitor Agent
resource azureMonitorAgent 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.25'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

// Data Collection Rule Association
resource dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-${namingPrefix}-${environment}'
  location: location
  tags: tags
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'perfCounterDataSource'
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            'Processor(*)\\% Processor Time'
            'Memory(*)\\Available MBytes'
            'Memory(*)\\% Used Memory'
            'Disk(*)\\% Free Space'
            'Disk(*)\\Disk Read Bytes/sec'
            'Disk(*)\\Disk Write Bytes/sec'
            'Network(*)\\Total Bytes'
          ]
        }
      ]
      syslog: [
        {
          name: 'syslogDataSource'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'authpriv'
            'cron'
            'daemon'
            'kern'
            'syslog'
          ]
          logLevels: [
            'Error'
            'Critical'
            'Alert'
            'Emergency'
            'Warning'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspaceId
          name: 'la-destination'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Perf'
          'Microsoft-Syslog'
        ]
        destinations: [
          'la-destination'
        ]
      }
    ]
  }
}

resource dcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  name: 'dcra-${namingPrefix}-${environment}'
  scope: vm
  properties: {
    dataCollectionRuleId: dcr.id
  }
}

// ============================================================================
// Backup Configuration
// ============================================================================

resource backupProtection 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-01-01' = if (enableBackup && !empty(recoveryServicesVaultName)) {
  name: '${recoveryServicesVaultName}/Azure/iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${vmName}/vm;iaasvmcontainerv2;${resourceGroup().name};${vmName}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    sourceResourceId: vm.id
    policyId: resourceId('Microsoft.RecoveryServices/vaults/backupPolicies', recoveryServicesVaultName, 'DailyBackupPolicy')
  }
}

// ============================================================================
// Auto-Shutdown Schedule
// ============================================================================

resource autoShutdownSchedule 'Microsoft.DevTestLab/schedules@2018-09-15' = if (enableAutoShutdown) {
  name: 'shutdown-computevm-${vmName}'
  location: location
  tags: tags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimeZone
    targetResourceId: vm.id
    notificationSettings: !empty(autoShutdownNotificationEmail) ? {
      status: 'Enabled'
      timeInMinutes: 30
      emailRecipient: autoShutdownNotificationEmail
      notificationLocale: 'en'
    } : {
      status: 'Disabled'
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The name of the VM')
output vmName string = vm.name

@description('The resource ID of the VM')
output vmId string = vm.id

@description('The private IP address of the VM')
output vmPrivateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress

@description('The principal ID of the VM managed identity')
output vmManagedIdentityPrincipalId string = vm.identity.principalId

@description('The name of the network interface')
output nicName string = nic.name

@description('The resource ID of the data collection rule')
output dataCollectionRuleId string = dcr.id
