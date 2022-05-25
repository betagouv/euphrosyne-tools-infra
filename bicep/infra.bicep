@description('Username for the VM admin user')
param adminUsername string

@description('Password for the VM admin user')
@minLength(12)
@secure()
param adminPassword string

@description('Project name related to the VM. Will be used as the username of the project user.')
param projectName string

@description('Password for the VM project password')
@minLength(12)
@secure()
param projectUserPassword string

@description('Location')
param location string = 'westeurope'

@description('Name for the Virtual Network')
param vnetName string = 'euphro-vm-vnet'

@description('Name for the Virtual Subnet')
param subnetName string = 'euphro-vm-subnet'

@description('Name of the virtual machine.')
param vmName string = 'simple-vm'

@description('Postdeploy Powershell script URL.')
param postdeployScriptURL string = 'https://raw.githubusercontent.com/betagouv/euphrosyne-tools-infra/main/powershell/postdeploy.ps1'

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

resource euphrosyneStg 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: 'euphrosynestorageaccount'
  resource service 'fileServices' existing = {
    name: 'default'

    resource share 'shares' existing = {
      name: 'euphrosyne-fileshare'
    }
  }
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

resource VmScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: '${vm.name}/postdepoy-script'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    settings: {
      storageAccountName: euphrosyneStg.name
      fileUris: [
        postdeployScriptURL
      ]
    }
    protectedSettings: {
      storageAccountKey: euphrosyneStg.listKeys().keys[0].value
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File postdeploy.ps1 -ProjectUserPassword ${projectUserPassword} -ProjectUsername ${projectName} -StorageAccountName ${euphrosyneStg.name} -StorageAccessKey ${euphrosyneStg.listKeys().keys[0].value} -FileshareName ${euphrosyneStg::service::share.name} -ProjectName ${projectName}'
    }
  }
  tags: defaultTags
}

output privateIPVM string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmID string = vmID
