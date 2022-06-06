@description('Username for the VM admin user')
param adminUsername string

@description('Password for the VM admin user')
@minLength(12)
@secure()
param adminPassword string

@description('Location')
param location string = 'westeurope'

@description('Resource prefix')
param resourcePrefix string = 'euphrosyne-01'

@description('Name for the Virtual Network')
param vnetName string = '${resourcePrefix}-vm-vnet'

@description('Name for the Virtual Subnet')
param subnetName string = '${resourcePrefix}-vm-subnet'

@description('Name of the virtual machine.')
param vmName string = 'simple-vm'

@allowed([
  'Standard_B8ms'
  'Standard_B20ms'
])
@description('VM Size, can be Standard_B8ms or Standard_B20ms')
param vmSize string = 'Standard_B8ms'

var defaultTags = {
  vmName: vmName
  fromTemplate: 'true'
}

resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${resourcePrefix}-vm-nic-${vmName}'
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
  name: '${resourcePrefix}-vm-${vmName}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
          diskSizeGB: 256
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
  }
  tags: defaultTags
}

output privateIPVM string = nic.properties.ipConfigurations[0].properties.privateIPAddress
