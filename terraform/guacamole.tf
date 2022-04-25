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
