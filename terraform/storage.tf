resource "azurerm_storage_account" "sa" {
  name                     = replace("${var.prefix}sa", "-", "")
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  // Keep the azurerm 3 defaults (azurerm 4+ defaults both to false).
  // Public nested items are required by the "static" container (access type "blob").
  allow_nested_items_to_be_public  = true
  cross_tenant_replication_enabled = true

  network_rules {
    default_action = "Allow"
  }
}

// Holds the scientific data despite its name. Renaming it would recreate the share.
resource "azurerm_storage_share" "guacd-storage-filetransfer" {
  name               = "${var.prefix}-guacd-filestransfer"
  storage_account_id = azurerm_storage_account.sa.id
  quota              = 102400

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_share" "common" {
  name               = "${var.prefix}-common"
  storage_account_id = azurerm_storage_account.sa.id
  quota              = 10
}

resource "azurerm_storage_container" "container-project-settings" {
  name                  = "project-settings"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "container-static" {
  name                  = "static"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "blob"
}

resource "azurerm_storage_container" "container-images" {
  name                  = "images"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "euphrosyne-data-cool" {
  name                  = "euphrosyne-data-cool"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "euphrosyne-data-cool" {
  storage_account_id = azurerm_storage_account.sa.id

  rule {
    name    = "force-euphrosyne-data-cool-tier"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${azurerm_storage_container.euphrosyne-data-cool.name}/"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 0
      }
    }
  }
}
