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
    image  = "guacamole/guacd:latest"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 4822
      protocol = "TCP"
    }
  }
}

// APP SERVICE
resource "azurerm_service_plan" "guac-service-plan" {
  name                = "${var.prefix}-guac-service-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "P1v2"
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

// BASTION VM
resource "azurerm_public_ip" "bastion-vm-pip" {
  name                    = "${var.prefix}-bastion-vm-pip"
  location                = var.location
  resource_group_name     = azurerm_resource_group.rg.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30

  tags = {
    "usage" = "bastion"
  }
}

resource "azurerm_network_interface" "bastion-vm-nic" {
  name                = "${var.prefix}-bastion-vm-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vmsubnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.bastion-vm-pip.id
  }

  tags = {
    "usage" = "bastion"
  }
}

resource "azurerm_linux_virtual_machine" "bastion-vm" {
  name                  = "${var.prefix}-bastion-vm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  size                  = "Standard_B1s"
  network_interface_ids = [azurerm_network_interface.bastion-vm-nic.id]

  admin_username                  = var.bastion_user
  admin_password                  = var.bastion_password
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  depends_on = [
    azurerm_mysql_flexible_database.guacd-db // Wait for the DB to be created before
  ]

  tags = {
    "usage" = "bastion"
  }
}

resource "azurerm_virtual_machine_extension" "bastion-vm-init-extension" {
  name                 = "${var.prefix}-bastion-vm-db-init-extension"
  virtual_machine_id   = azurerm_linux_virtual_machine.bastion-vm.id
  publisher            = "Microsoft.CPlat.Core"
  type                 = "RunCommandLinux"
  type_handler_version = "1.0"

  settings = <<SETTINGS
  {
      "commandToExecute": "sudo apt-get -y update && sudo apt-get -y install docker.io mysql-client-core-8.0 && sudo docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --mysql > initdb.sql && sudo mysql --host=\"${azurerm_mysql_flexible_server.guacd-db.fqdn}\" --user=\"${var.admin_sql_user}\" --password=\"${nonsensitive(azurerm_key_vault_secret.sql-secret-password.value)}\" --database=\"guacamole\" < initdb.sql"
  }
  SETTINGS

  tags = {
    "usage" = "bastion"
  }
}
