terraform {
  required_version = ">= 1.3.0"

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

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

resource "azurerm_network_security_group" "ssh_nsg" {
  name                = "ci-cd-nsg"
  location            = azurerm_resource_group.ci_cd_rg.location
  resource_group_name = azurerm_resource_group.ci_cd_rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
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

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.ssh_nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "ci-cd-vm"
  resource_group_name   = azurerm_resource_group.ci_cd_rg.name
  location              = azurerm_resource_group.ci_cd_rg.location
  size                  = "Standard_B2s"
  admin_username        = var.vm_username
  admin_password        = var.vm_password
  network_interface_ids = [azurerm_network_interface.nic.id]

  disable_password_authentication = true
  
  admin_ssh_key {
    username   = var.vm_username
    public_key = file("${path.module}/ci_cd_key.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # FULL AUTOMATION: install all dependencies
  custom_data = base64encode(<<-EOT
#!/bin/bash
set -e

# Update & Install packages
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io curl conntrack socat tar git build-essential golang-go make sshpass

# Enable Docker
usermod -aG docker ${var.vm_username}
systemctl enable docker
systemctl restart docker

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube

# Install CNI plugins
mkdir -p /opt/cni/bin
curl -L https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz | tar -C /opt/cni/bin -xz

# Install cri-dockerd
git clone https://github.com/Mirantis/cri-dockerd.git /tmp/cri-dockerd
cd /tmp/cri-dockerd
make cri-dockerd
cp cri-dockerd /usr/local/bin/
cp packaging/systemd/* /etc/systemd/system/
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl start cri-docker.service

# Ensure conntrack is in PATH
ln -s /usr/sbin/conntrack /usr/local/bin/conntrack || true
EOT
  )
}
