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

@description('Name of the snapshot to use')
param snapshotName string

@description('Name of the disk setup to use')
param snapshotDiskName string

@description('Availibility zones')
param zones array = ['3']

var defaultTags = {
  vmName: vmName
  fromTemplate: 'true'
}

resource disk 'Microsoft.Compute/disks@2022-03-02' = {
  name: '${resourcePrefix}-vm-disk-${vmName}'
  location: location
  properties: {
    creationData: {
      createOption: 'copy'
      sourceResourceId: resourceId('Microsoft.Compute/snapshots', snapshotName)
    }
    diskSizeGB: 128
    encryption: {
      type: 'EncryptionAtRestWithPlatformKey'
    }
    networkAccessPolicy: 'AllowPrivate'
    publicNetworkAccess: 'Disabled'
    diskAccessId: resourceId('Microsoft.Compute/diskAccesses', snapshotDiskName) 
  }
  sku: {
    name:'Premium_LRS'
  }
  zones: zones
  tags: defaultTags
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
        createOption: 'Attach'
        osType: 'Windows'
        managedDisk: {
          id: disk.id
        }
        deleteOption: 'Delete'
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
