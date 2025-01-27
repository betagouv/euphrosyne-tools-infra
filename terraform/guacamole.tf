// Database
resource "azurerm_mysql_flexible_database" "guacd-db" {
  name                = "guacamole"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.guacd-db.name
  charset             = "utf8mb3"
  collation           = "utf8mb3_unicode_ci"
}

// CONTAINER
resource "azurerm_container_group" "guacd-container" {
  name                = "${var.prefix}-guacd-container"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "Private"
  subnet_ids          = [azurerm_subnet.guacdsubnet.id]
  os_type             = "Linux"

  container {
    name   = "guacd"
    image  = "guacamole/guacd:1.5.1"
    cpu    = "1"
    memory = "2"

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

  image_registry_credential {
    server   = "index.docker.io"
    username = var.image_registry_credential_username
    password = var.image_registry_credential_password
  }
}

// APP SERVICE
resource "azurerm_linux_web_app" "guacamole-web-app" {
  name                = "${var.prefix}-guacamole"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.guac-service-plan.id
  https_only          = true

  site_config {
    application_stack {
      docker_image     = "guacamole/guacamole"
      docker_image_tag = "1.5.1"
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

