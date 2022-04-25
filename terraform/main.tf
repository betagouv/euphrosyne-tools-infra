terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vmsubnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "guacsubnet" {
  name                 = "guac-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "sqlsubnet" {
  name                 = "sql-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "dlg-Microsoft.DBforMySQL-flexibleServers"

    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.DBforMySQL/flexibleServers"
    }
  }
}

resource "azurerm_network_security_group" "guacd-network-security" {
  name                = "accept-guacd-from-guac"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-guacd-from-guac"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 4822
    source_address_prefix      = azurerm_subnet.guacsubnet.address_prefixes.0
    destination_address_prefix = "*"
  }
}

resource "azurerm_private_dns_zone" "private-dns" {
  name                = "guacd-db.private.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
  soa_record {
    email        = "azureprivatedns-host.microsoft.com"
    expire_time  = 2419200
    minimum_ttl  = 10
    refresh_time = 3600
    retry_time   = 300
    ttl          = 3600
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "private-dns-to-vnet" {
  name                  = "kfknbs5twsw6q"
  private_dns_zone_name = azurerm_private_dns_zone.private-dns.name
  resource_group_name   = azurerm_resource_group.rg.name
  registration_enabled  = false
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_subnet_network_security_group_association" "rdp-guac-security-to-vm" {
  subnet_id                 = azurerm_subnet.vmsubnet.id
  network_security_group_id = azurerm_network_security_group.guacd-network-security.id
}

resource "azurerm_automation_account" "vm-automation-acc" {
  name                = "vm-automation-acc"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"
}

resource "azurerm_mysql_flexible_server" "guacd-db" {
  name                   = "guacamole-db"
  administrator_login    = "maxime"
  administrator_password = ""
  backup_retention_days  = 7
  location               = var.location
  delegated_subnet_id    = azurerm_subnet.sqlsubnet.id
  resource_group_name    = azurerm_resource_group.rg.name
  private_dns_zone_id    = azurerm_private_dns_zone.private-dns.id
  sku_name               = "B_Standard_B1s"
  version                = "8.0.21"
  zone                   = "1"
  replication_role       = "None"
  storage {
    auto_grow_enabled = true
    iops              = 360
    size_gb           = 20
  }
}

resource "azurerm_service_plan" "guac-service-plan" {
  name                = "guac-service-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "guacd-app" {
  name                = "guacd-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.guac-service-plan.id

  site_config {
    application_stack {
      docker_image     = "guacamole/guacd"
      docker_image_tag = "latest"
    }
    ip_restriction {
      virtual_network_subnet_id = azurerm_subnet.vmsubnet.id
    }
  }
}
