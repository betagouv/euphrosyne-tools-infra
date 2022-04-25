@description('Username for the VM')
param adminUsername string

@description('Password for the VM')
@minLength(12)
@secure()
param adminPassword string

@description('Location')
param location string = 'northeurope'

@description('Name for the Virtual Network')
param vnetName string = 'vm-vnet'

@description('Name for the Virtual Subnet')
param subnetName string = 'vm-subnet'

@description('Name of the virtual machine.')
param vmName string = 'simple-vm'

var vmID = uniqueString(resourceGroup().id, vmName)
var defaultTags = {
  vmName: vmName
  vmID: vmID
  fromTemplate: 'true'
}

resource stg 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'bootdiag${vmID}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  tags: defaultTags
}

resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'vm-nic-${vmID}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig-01'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
  }
  tags: defaultTags
}

resource vm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: 'vm-${vmID}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2as_v4'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-datacenter-gensecond'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: stg.properties.primaryEndpoints.blob
      }
    }
  }
  tags: defaultTags
}

output privateIPVM string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmID string = vmID
