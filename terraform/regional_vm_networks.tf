resource "azurerm_virtual_network" "regional_vm" {
  for_each = var.regional_vm_networks

  name                = "${var.prefix}-${each.key}-vm-vnet"
  address_space       = each.value.address_space
  location            = each.value.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "regional_vm" {
  for_each = var.regional_vm_networks

  name                 = "${var.prefix}-${each.key}-vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.regional_vm[each.key].name
  address_prefixes     = each.value.vm_subnet_prefixes

  private_endpoint_network_policies_enabled = true

  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_virtual_network_peering" "core_to_regional" {
  for_each = var.regional_vm_networks

  name                      = "${var.prefix}-core-to-${each.key}-peering"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet.name
  remote_virtual_network_id = azurerm_virtual_network.regional_vm[each.key].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "regional_to_core" {
  for_each = var.regional_vm_networks

  name                      = "${var.prefix}-${each.key}-to-core-peering"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.regional_vm[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
