resource "azurerm_private_dns_zone" "sql-private-dns" {
  name                = "euphrosyne.mysql.database.azure.com"
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

resource "azurerm_private_dns_zone_virtual_network_link" "sql-private-dns-to-vnet" {
  name                  = "${var.prefix}-sql-private-dns-vn-link"
  private_dns_zone_name = azurerm_private_dns_zone.sql-private-dns.name
  resource_group_name   = azurerm_resource_group.rg.name
  registration_enabled  = false
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_zone" "private-dns" {
  name                = "euphrosyne.azure.com"
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
  name                  = "${var.prefix}-private-dns-vn-link"
  private_dns_zone_name = azurerm_private_dns_zone.private-dns.name
  resource_group_name   = azurerm_resource_group.rg.name
  registration_enabled  = false
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

// Database

resource "random_password" "sql-random-password" {
  length  = 20
  special = true
}

resource "azurerm_key_vault_secret" "sql-secret-password" {
  name         = "${var.prefix}-sql-secret-password"
  value        = random_password.sql-random-password.result
  key_vault_id = azurerm_key_vault.key-vault.id
  depends_on = [
    azurerm_key_vault.key-vault
  ]
}

resource "azurerm_mysql_flexible_server" "guacd-db" {
  name                   = "${var.prefix}-guacamole-sql-server"
  administrator_login    = "maxime"
  administrator_password = azurerm_key_vault_secret.sql-secret-password.value
  backup_retention_days  = 7
  location               = var.location
  delegated_subnet_id    = azurerm_subnet.sqlsubnet.id
  resource_group_name    = azurerm_resource_group.rg.name
  private_dns_zone_id    = azurerm_private_dns_zone.sql-private-dns.id
  sku_name               = "B_Standard_B1s"
  version                = "8.0.21"
  zone                   = "1"
  storage {
    auto_grow_enabled = true
    iops              = 360
    size_gb           = 20
  }

  timeouts {
    create = "12h"
  }
}

resource "azurerm_mysql_flexible_database" "guacd-db" {
  name                = "guacamole"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.guacd-db.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

resource "azurerm_service_plan" "guac-service-plan" {
  name                = "${var.prefix}-guac-service-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "guacd-app" {
  name                = "${var.prefix}-guacd"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.guac-service-plan.id

  site_config {
    application_stack {
      docker_image     = "guacamole/guacd"
      docker_image_tag = "latest"
    }
  }
}

resource "azurerm_private_endpoint" "guacd-private-end" {
  name                = "${var.prefix}-guacd-private-endpoint"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.vmsubnet.id

  private_dns_zone_group {
    name                 = "guacd-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.private-dns.id]
  }

  private_service_connection {
    name                           = "guacd-private-connection"
    private_connection_resource_id = azurerm_linux_web_app.guacd-app.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_dns_a_record" "guacd-a-record" {
  name                = "${var.prefix}-guacd-a-record"
  zone_name           = azurerm_private_dns_zone.private-dns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = azurerm_private_endpoint.guacd-private-end.custom_dns_configs.0.ip_addresses
}

resource "azurerm_linux_web_app" "guacamole-web-app" {
  name                = "${var.prefix}-guacamole"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.guac-service-plan.id
  https_only          = true

  site_config {
    application_stack {
      docker_image     = "guacamole/guacamole"
      docker_image_tag = "latest"
    }
  }

  app_settings = {
    "GUACD_HOSTNAME"             = azurerm_private_endpoint.guacd-private-end.custom_dns_configs.0.fqdn
    "MYSQL_HOSTNAME"             = azurerm_mysql_flexible_server.guacd-db.fqdn
    "MYSQL_DATABASE"             = azurerm_mysql_flexible_database.guacd-db.name
    "MYSQL_USER"                 = "maxime"
    "MYSQL_PASSWORD"             = azurerm_key_vault_secret.sql-secret-password.value
    "EXTENSIONS"                 = "auth-header"
    "HEADER_ENABLED"             = "true"
    "WEBSITE_DNS_SERVER"         = "168.63.129.16"
    "WEBSITE_VNET_ROUTE_ALL"     = "1"
    "MYSQL_AUTO_CREATE_ACCOUNTS" = "true"
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "guacamole-connection" {
  app_service_id = azurerm_linux_web_app.guacamole-web-app.id
  subnet_id      = azurerm_subnet.guacsubnet.id
}
