// Network security groups
//
// Without them, Azure allows all traffic inside the VNet and its peerings:
// a project VM can reach other project VMs, guacd and the Guacamole database.
// Only the flows Guacamole needs are kept:
// Guacamole web app -> guacd (4822) and MySQL (3306), guacd -> VMs (RDP 3389).
// Traffic to Azure Storage and Internet is not restricted here.

// VM subnets
resource "azurerm_network_security_group" "vm" {
  name                = "${var.prefix}-vm-subnet-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowRdpFromGuacd"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = azurerm_subnet.guacdsubnet.address_prefixes
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyVnetInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyVnetOutbound"
    priority                   = 4000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "vm" {
  subnet_id                 = azurerm_subnet.vmsubnet.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

// An NSG must be in the same region as its subnet.
resource "azurerm_network_security_group" "regional_vm" {
  for_each = var.regional_vm_networks

  name                = "${var.prefix}-${each.key}-vm-subnet-nsg"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowRdpFromGuacd"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = azurerm_subnet.guacdsubnet.address_prefixes
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyVnetInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyVnetOutbound"
    priority                   = 4000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "regional_vm" {
  for_each = var.regional_vm_networks

  subnet_id                 = azurerm_subnet.regional_vm[each.key].id
  network_security_group_id = azurerm_network_security_group.regional_vm[each.key].id
}

// guacd does not authenticate its clients: only the Guacamole web app may reach it.
resource "azurerm_network_security_group" "guacd" {
  name                = "${var.prefix}-guac-private-subnet-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowGuacdFromGuacamole"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4822"
    source_address_prefixes    = azurerm_subnet.guacsubnet.address_prefixes
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyVnetInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "guacd" {
  subnet_id                 = azurerm_subnet.guacdsubnet.id
  network_security_group_id = azurerm_network_security_group.guacd.id
}

resource "azurerm_network_security_group" "sql" {
  name                = "${var.prefix}-sql-subnet-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowMysqlFromGuacamole"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefixes    = azurerm_subnet.guacsubnet.address_prefixes
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyVnetInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "sql" {
  subnet_id                 = azurerm_subnet.sqlsubnet.id
  network_security_group_id = azurerm_network_security_group.sql.id
}
