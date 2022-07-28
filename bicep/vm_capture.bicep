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

resource gallery 'Microsoft.Compute/galleries/images/versions@2022-01-03' = {
  name: '${galleryName}/${imageDefinitionName}/${version}'
  location: location 
  properties: {
    publishingProfile: {
      replicaCount: 1
      targetRegions: [
        {
          name: location
          regionalReplicaCount:1
          storageAccountType: 'Standard_LRS'
        }
      ]
      excludeFromLatest: false
    }
    storageProfile: {
      source: {
        id: resourceId('Microsoft.Compute/virtualMachines', vmName)
      }
    }
  }
}
