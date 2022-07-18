
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
