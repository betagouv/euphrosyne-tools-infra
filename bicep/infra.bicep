// version 1.11

@description('Location')
param location string = 'westeurope'

@description('Resource prefix')
param resourcePrefix string = 'euphrosyne-01'

@description('Name for the Virtual Network')
param vnetName string = '${resourcePrefix}-vm-vnet'

@description('Name for the Virtual Subnet')
param subnetName string = '${resourcePrefix}-vm-subnet'

@description('Project name')
param projectName string = 'Simple project'

@description('Name of the virtual machine.')
param vmName string = 'simple-vm'

@allowed([
  'Standard_B8ms'
  'Standard_B20ms'
])
@description('VM Size, can be Standard_B8ms or Standard_B20ms')
param vmSize string = 'Standard_B8ms'

@description('Name of account using the VM')
param accountName string

@secure()
@description('Name of account using the VM')
param accountPassword string

@description('Availibility zones')
param zones array = [ '3' ]

@description('Image gallery to fetch the vm image')
param imageGallery string = 'euphrostgvmimagegallery'

@description('Image definition')
param imageDefinition string = 'euphro-stg-base-win-vm-image'

@description('Version used for the image, default to latest')
param imageVersion string = 'latest'

@description('FileShare name')
param fileShareName string

@description('Storage account name')
param storageAccountName string

var defaultTags = {
  vmName: vmName
  fromTemplate: 'true'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
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
        id: resourceId('Microsoft.Compute/galleries/images/versions', imageGallery, imageDefinition, imageVersion)
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

  resource vmMountDriveExtension 'extensions@2022-08-01' = {
    name: 'mountDriveExtension'
    location: location
    properties: {
      settings: any({
        fileUris: [
          'https://raw.githubusercontent.com/betagouv/euphrosyne-tools-infra/main/bicep/mountDrive.ps1'
          'https://raw.githubusercontent.com/betagouv/euphrosyne-tools-infra/main/lib/PSTools/2.48/PsExec.exe'
        ]
      })
      protectedSettings: any({
        commandToExecute: 'powershell -Command "Enable-PSRemoting -Force" ;.\\psexec -u ${accountName} -p ${accountPassword} -accepteula -h -i "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -File \${pwd}\\mountDrive.ps1 -FileShare ${fileShareName} -StorageAccountAccessKey ${storageAccount.listKeys().keys[0].value} -StorageAccount ${storageAccount.name} -ProjectName ${projectName}'
      })
      publisher: 'Microsoft.Compute'
      type: 'CustomScriptExtension'
      typeHandlerVersion: '1.10'
    }
  }
}

output privateIPVM string = nic.properties.ipConfigurations[0].properties.privateIPAddress
