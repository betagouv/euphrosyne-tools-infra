// SQL DNS
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

// Database
resource "random_password" "sql-random-password" {
  length  = 20
  special = true
}

resource "azurerm_key_vault_secret" "sql-secret-password" {
  name         = "${var.prefix}-sql-secret-password"
  value        = random_password.sql-random-password.result
  key_vault_id = azurerm_key_vault.key-vault.id
}

resource "azurerm_mysql_flexible_server" "guacd-db" {
  name                   = "${var.prefix}-guacamole-sql-server"
  administrator_login    = var.admin_sql_user
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
}

resource "azurerm_mysql_flexible_database" "guacd-db" {
  name                = "guacamole"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.guacd-db.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

// CONTAINER
resource "azurerm_network_profile" "guacd-np" {
  name                = "${var.prefix}-guacd-np"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  container_network_interface {
    name = "guacd-np-nic"

    ip_configuration {
      name      = "guacd-np-ipconfig"
      subnet_id = azurerm_subnet.guacdsubnet.id
    }
  }
}

resource "azurerm_container_group" "guacd-container" {
  name                = "${var.prefix}-guacd-container"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "Private"
  network_profile_id  = azurerm_network_profile.guacd-np.id
  os_type             = "Linux"

  container {
    name   = "guacd"
    image  = "guacamole/guacd:1.4.0"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 4822
      protocol = "TCP"
    }

    volume {
      name                 = "${var.prefix}-guacd-filetransfer-volume"
      mount_path           = "/filetransfer"
      storage_account_name = azurerm_storage_account.sa.name
      storage_account_key  = azurerm_storage_account.sa.primary_access_key
      share_name           = azurerm_storage_share.guacd-storage-filetransfer.name
    }
  }
}

// APP SERVICE
resource "azurerm_service_plan" "guac-service-plan" {
  name                = "${var.prefix}-guac-service-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "S2"
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
      docker_image_tag = "1.4.0"
    }
  }

  app_settings = {
    "GUACD_HOSTNAME"             = azurerm_container_group.guacd-container.ip_address
    "MYSQL_HOSTNAME"             = azurerm_mysql_flexible_server.guacd-db.fqdn
    "MYSQL_DATABASE"             = azurerm_mysql_flexible_database.guacd-db.name
    "MYSQL_USER"                 = var.admin_sql_user
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
