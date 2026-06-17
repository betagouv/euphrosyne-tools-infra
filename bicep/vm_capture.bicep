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
        virtualMachineId: resourceId('Microsoft.Compute/virtualMachines', vmName)
      }
    }
  }
}
