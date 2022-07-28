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

@description('Availibility zones')
param zones array = ['3']


var defaultTags = {
  vmName: vmName
  fromTemplate: 'true'
}

resource nic 'Microsoft.Network/networkInterfaces@2022-01-01' = {
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

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: '${resourcePrefix}-vm-${vmName}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'fromImage'
        osType: 'Windows'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
      }
      imageReference: {
        id: resourceId('Microsoft.Compute/galleries/images/versions', 'euphrosyne01vmimagegallery', 'euphrosyne-01-base-win-vm-image', '0.1.0')
      }
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
    licenseType: 'Windows_Client'
  }
  zones: zones
  tags: defaultTags
}

output privateIPVM string = nic.properties.ipConfigurations[0].properties.privateIPAddress
