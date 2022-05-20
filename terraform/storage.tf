resource "azurerm_storage_account" "sa" {
  name                     = "euphrosyne01stg"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "euphrosyne_fileshare" {
  name                 = "${var.prefix}-fileshare"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 50
}
