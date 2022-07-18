resource "azurerm_storage_account" "sa" {
  name                     = "euphrosyne01stg"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action = "Allow"
  }
}

resource "azurerm_storage_share" "guacd-storage-filetransfer" {
  name                 = "${var.prefix}-guacd-filestransfer"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 50
}

resource "azurerm_storage_share" "common" {
  name                 = "${var.prefix}-common"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 10
}
