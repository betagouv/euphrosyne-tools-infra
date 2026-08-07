resource "azapi_resource" "albert_session_pool" {
  count = var.create_albert_session_pool ? 1 : 0

  type      = "Microsoft.App/sessionPools@2025-07-01"
  name      = lower(replace("${var.prefix}albert", "-", ""))
  parent_id = azurerm_resource_group.rg.id
  location  = azurerm_resource_group.rg.location

  body = {
    properties = {
      poolManagementType = "Dynamic"
      containerType      = "PythonLTS"
      scaleConfiguration = {
        maxConcurrentSessions = 5
        readySessionInstances = 0
      }
      dynamicPoolConfiguration = {
        lifecycleConfiguration = {
          lifecycleType           = "Timed"
          cooldownPeriodInSeconds = 300
        }
      }
      sessionNetworkConfiguration = {
        status = "EgressDisabled"
      }
    }
  }

  response_export_values = ["properties.poolManagementEndpoint"]
}

output "albert_session_pool_endpoint" {
  description = "Session pool endpoint."
  value = try(
    azapi_resource.albert_session_pool[0].output.properties.poolManagementEndpoint,
    null,
  )
}
