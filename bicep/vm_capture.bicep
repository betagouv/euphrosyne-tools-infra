@description('Location')
param location string = 'westeurope'

@description('Gallery name')
param galleryName string = 'euphrosyne01vmimagegallery'

@description('Image definition name')
param imageDefinitionName string = 'euphrosyne-01-base-win-vm-image'

@description('VM name used to create new version')
param vmName string

@description('Version')
param version string

@description('Regions where the image version should be replicated')
param targetRegionNames array = [
  location
]

@description('Force update tag for the cleanup extension so it reruns on each capture deployment')
param cleanupForceUpdateTag string = utcNow()

// Windows VMs support only one Microsoft.Compute.CustomScriptExtension handler.
// This must match the extension resource created by infra.bicep.
var customScriptExtensionName = 'mountedDriveManagementExtension'

resource sourceVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: vmName
}

resource cleanupBeforeCaptureExtension 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: sourceVm
  name: customScriptExtensionName
  location: location
  properties: {
    settings: any({
      fileUris: [
        'https://raw.githubusercontent.com/betagouv/euphrosyne-tools-infra/refs/heads/feat/tomo-infra-bicep/bicep/cleanupBeforeCapture.ps1'
      ]
    })
    protectedSettings: any({
      commandToExecute: 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\cleanupBeforeCapture.ps1'
    })
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    forceUpdateTag: cleanupForceUpdateTag
  }
}

resource gallery 'Microsoft.Compute/galleries/images/versions@2024-03-03' = {
  name: '${galleryName}/${imageDefinitionName}/${version}'
  location: location
  properties: {
    publishingProfile: {
      replicaCount: 1
      targetRegions: [for targetRegionName in targetRegionNames: {
        name: targetRegionName
        regionalReplicaCount: 1
        storageAccountType: 'Standard_LRS'
      }]
      excludeFromLatest: false
    }
    storageProfile: {
      source: {
        virtualMachineId: sourceVm.id
      }
    }
  }
  dependsOn: [
    cleanupBeforeCaptureExtension
  ]
}
