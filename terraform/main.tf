terraform {
  required_version = ">= 1.3.0"

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Backend resources (will switch to remote backend later)
resource "azurerm_resource_group" "backend_rg" {
  name     = "rg-terraform-state"
  location = var.location
}

resource "azurerm_storage_account" "backend_sa" {
  name                     = "tfstateaccount${random_integer.suffix.result}"
  resource_group_name      = azurerm_resource_group.backend_rg.name
  location                 = azurerm_resource_group.backend_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "backend_container" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.backend_sa.name
  container_access_type = "private"
}

resource "random_integer" "suffix" {
  min = 1000
  max = 9999
}

# Actual infra resources
resource "azurerm_resource_group" "ci_cd_rg" {
  name     = "ci-cd-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "ci-cd-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.ci_cd_rg.location
  resource_group_name = azurerm_resource_group.ci_cd_rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "ci-cd-subnet"
  resource_group_name  = azurerm_resource_group.ci_cd_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "vm_pip" {
  name                = "ci-cd-pip"
  location            = azurerm_resource_group.ci_cd_rg.location
  resource_group_name = azurerm_resource_group.ci_cd_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "ci-cd-nic"
  location            = azurerm_resource_group.ci_cd_rg.location
  resource_group_name = azurerm_resource_group.ci_cd_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "ci-cd-vm"
  resource_group_name   = azurerm_resource_group.ci_cd_rg.name
  location              = azurerm_resource_group.ci_cd_rg.location
  size                  = "Standard_B2s"
  admin_username        = var.vm_username
  admin_password        = var.vm_password
  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
