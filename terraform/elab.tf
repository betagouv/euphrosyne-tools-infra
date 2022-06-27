resource "azurerm_mysql_flexible_database" "elab-db" {
  name                = "elabftw"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.guacd-db.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

resource "azurerm_linux_web_app" "elab-web-app" {
  name                = "${var.prefix}-elab"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.guac-service-plan.id
  https_only          = true

  site_config {
    application_stack {
      docker_image     = "elabftw/elabimg"
      docker_image_tag = "4.3.5"
    }
  }

  storage_account {
    type         = "AzureFiles"
    account_name = azurerm_storage_account.sa.name
    access_key   = azurerm_storage_account.sa.primary_access_key
    name         = "${var.prefix}-elab-upload"
    share_name   = azurerm_storage_share.elab-storage.name
    mount_path   = "/elabftw/uploads"
  }

  storage_account {
    type         = "AzureFiles"
    account_name = azurerm_storage_account.sa.name
    access_key   = azurerm_storage_account.sa.primary_access_key
    name         = "${var.prefix}-elab-common"
    share_name   = azurerm_storage_share.common.name
    mount_path   = "/commons"
  }

  app_settings = {
    "DB_HOST"                = azurerm_mysql_flexible_server.guacd-db.fqdn
    "DB_USER"                = var.admin_sql_user
    "DB_PASSWORD"            = azurerm_key_vault_secret.sql-secret-password.value
    "DB_NAME"                = azurerm_mysql_flexible_database.elab-db.name
    "PHP_TIMEZONE"           = "Europe/Paris"
    "TZ"                     = "Europe/Paris"
    "SECRET_KEY"             = var.elab_secret_key
    "SITE_URL"               = "https://${var.prefix}-elab.azurewebsites.net"
    "DISABLE_HTTPS"          = true
    "ENABLE_LETSENCRYPT"     = false
    "DEV_MODE"               = true
    "WEBSITE_DNS_SERVER"     = "168.63.129.16"
    "WEBSITE_VNET_ROUTE_ALL" = "1"
    "DB_CERT_PATH"           = "/commons/mysql/DigiCertGlobalRootCA.crt.pem"
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "elab-connection" {
  app_service_id = azurerm_linux_web_app.elab-web-app.id
  subnet_id      = azurerm_subnet.guacsubnet.id
}
