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

// SQL Server
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
  sku_name               = "B_Standard_B1ms"
  version                = "8.0.21"
  zone                   = "1"
  storage {
    auto_grow_enabled = true
    iops              = 360
    size_gb           = 20
  }
}
