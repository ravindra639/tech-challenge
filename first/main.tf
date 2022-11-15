terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.20.0"
    }
  }
}
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "RSG-VM" {
  name     = "RSG-VM"
  location = "Central US"
}

resource "azurerm_virtual_network" "VN-VM" {
  name                = "VM-network"
  address_space       = ["129.0.0.0/16"]
  location            = azurerm_resource_group.RSG-VM.location
  resource_group_name = azurerm_resource_group.RSG-VM.name
}

resource "azurerm_subnet" "sub-VM" {
  name                 = "sub-internal"
  resource_group_name  = azurerm_resource_group.RSG-VM.name
  virtual_network_name = azurerm_virtual_network.VN-VM.name
  address_prefixes     = ["129.0.2.0/24"]
}
resource "azurerm_network_security_group" "NSG-VM" {
  name                = "Network-SG"
  location            = azurerm_resource_group.RSG-VM.location
  resource_group_name = azurerm_resource_group.RSG-VM.name
}
resource "azurerm_network_interface" "nic" {
  count               = var.vm_count
  name                = "${var.vm_name_pfx}-${count.index}-nic"
  location            = azurerm_resource_group.RSG-VM.location
  resource_group_name = azurerm_resource_group.RSG-VM.name
 
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sub-VM.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_network_interface_security_group_association" "NIS-ASSOCIATE" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.NSG-VM.id
}
resource "azurerm_network_security_rule" "NS-Rule" {
    name = "RDP"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "3389"
    source_address_prefix = "*"
    destination_address_prefix = "*"
    network_security_group_name = azurerm_network_security_group.NSG-VM.name
    resource_group_name = azurerm_resource_group.RSG-VM.name
}
resource "azurerm_windows_virtual_machine" "vm" {
  count               = var.vm_count # Count Value read from variable
  name                = "${var.vm_name_pfx}-${count.index}" # Name constructed using count and pfx
  resource_group_name = azurerm_resource_group.RSG-VM.name
  location            = azurerm_resource_group.RSG-VM.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "Adminhost@123"
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
   source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}
