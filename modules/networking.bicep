// ============================================================================
// Networking Module - VNet, Subnets, NSG
// ============================================================================
// Description: Creates virtual network, subnets, and network security group
// ============================================================================

@description('Azure region for resources')
param location string

@description('Environment name')
param environment string

@description('Resource tags')
param tags object

@description('Project name for resource naming')
param namingPrefix string

@description('Virtual Network address space')
param vnetAddressPrefix string

@description('Application subnet address prefix')
param appSubnetPrefix string

@description('Allowed IP ranges for SSH access')
param sshAllowedSourceAddresses array

@description('Allowed IP ranges for HTTPS access')
param httpsAllowedSourceAddresses array

// ============================================================================
// Variables
// ============================================================================

var vnetName = 'vnet-${namingPrefix}-spoke-${environment}'
var appSubnetName = 'snet-${namingPrefix}-app-${environment}'
var nsgName = 'nsg-${namingPrefix}-app-${environment}'

// ============================================================================
// Network Security Group
// ============================================================================

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      // Inbound Rules
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          description: 'Allow HTTPS from Netskope or corporate ranges'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: !empty(httpsAllowedSourceAddresses) && length(httpsAllowedSourceAddresses) == 1 ? httpsAllowedSourceAddresses[0] : '*'
          sourceAddressPrefixes: !empty(httpsAllowedSourceAddresses) && length(httpsAllowedSourceAddresses) > 1 ? httpsAllowedSourceAddresses : null
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-SSH-Inbound'
        properties: {
          description: 'Allow SSH from management subnet or jump host'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: !empty(sshAllowedSourceAddresses) && length(sshAllowedSourceAddresses) == 1 ? sshAllowedSourceAddresses[0] : '*'
          sourceAddressPrefixes: !empty(sshAllowedSourceAddresses) && length(sshAllowedSourceAddresses) > 1 ? sshAllowedSourceAddresses : null
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
      // Outbound Rules
      {
        name: 'Allow-HTTPS-Outbound'
        properties: {
          description: 'Allow HTTPS outbound for Azure services and updates'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-HTTP-Outbound'
        properties: {
          description: 'Allow HTTP outbound for package updates'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-AzureStorage-Outbound'
        properties: {
          description: 'Allow access to Azure Storage'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-AzureMonitor-Outbound'
        properties: {
          description: 'Allow access to Azure Monitor'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'Allow-VNet-Outbound'
        properties: {
          description: 'Allow communication within VNet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
    ]
  }
}

// ============================================================================
// Virtual Network
// ============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: appSubnetName
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The name of the virtual network')
output vnetName string = vnet.name

@description('The resource ID of the virtual network')
output vnetId string = vnet.id

@description('The name of the app subnet')
output appSubnetName string = appSubnetName

@description('The resource ID of the app subnet')
output appSubnetId string = vnet.properties.subnets[0].id

@description('The resource ID of the NSG')
output nsgId string = nsg.id

@description('The name of the NSG')
output nsgName string = nsg.name
