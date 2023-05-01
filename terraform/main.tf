terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.54.0"
    }
    random = {}
  }

  backend "azurerm" {
    resource_group_name  = "Euphrosyne_tfstate"
    storage_account_name = "euphrosynetfstate"
    container_name       = "tfstate"
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

provider "random" {
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_key_vault" "key-vault" {
  name                       = "${var.prefix}-key-vault"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.rg.name
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get"
    ]

    secret_permissions = [
      "Get", "Backup", "Delete", "List", "Purge", "Recover", "Restore", "Set",
    ]

    storage_permissions = [
      "Get"
    ]
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vmsubnet" {
  name                 = "${var.prefix}-vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  private_endpoint_network_policies_enabled = true

  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_subnet" "guacsubnet" {
  name                 = "${var.prefix}-guac-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "delegation"

    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }
}

resource "azurerm_subnet" "sqlsubnet" {
  name                 = "${var.prefix}-sql-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "dlg-Microsoft.DBforMySQL-flexibleServers"

    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.DBforMySQL/flexibleServers"
    }
  }
}

resource "azurerm_subnet" "guacdsubnet" {
  name                 = "${var.prefix}-guac-private-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/24"]

  service_endpoints = ["Microsoft.Storage"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

// App Service
resource "azurerm_service_plan" "guac-service-plan" {
  name                = "${var.prefix}-guac-service-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "S2"
}

// VM Images
resource "azurerm_shared_image_gallery" "vm-image-gallery" {
  name                = replace("${var.prefix}-vm-image-gallery", "-", "")
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  description         = "Gallery to hold VM images"
}

resource "azurerm_shared_image" "base-vm-image" {
  name                = "${var.prefix}-base-win-vm-image"
  gallery_name        = azurerm_shared_image_gallery.vm-image-gallery.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Windows"
  hyper_v_generation  = "V2"
  specialized         = true

  identifier {
    publisher = "microsoftwindowsdesktop"
    offer     = "office-365"
    sku       = "win10-21h2-avd-m365-g2"
  }
}
