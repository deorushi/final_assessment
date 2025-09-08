terraform {
  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Resource Group
resource "azurerm_resource_group" "ci_cd_rg" {
  name     = "ci-cd-rg"
  location = var.location
}

# VNet/subnet
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

# Public IP
resource "azurerm_public_ip" "vm_pip" {
  name                = "ci-cd-pip"
  location            = azurerm_resource_group.ci_cd_rg.location
  resource_group_name = azurerm_resource_group.ci_cd_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NSG allowing SSH (22)
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

# NIC
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

# NSG association
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.ssh_nsg.id
}

# VM: cloud-init installs everything at first boot
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "ci-cd-vm"
  resource_group_name   = azurerm_resource_group.ci_cd_rg.name
  location              = azurerm_resource_group.ci_cd_rg.location
  size                  = "Standard_B2s"
  admin_username        = var.vm_username
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

  # IMPORTANT: cloud-init script. Use $$ where you would use $ in shell variables.
  custom_data = base64encode(<<-EOT
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Basic packages
apt-get update -y
apt-get install -y docker.io curl conntrack socat tar git build-essential golang-go make wget unzip

# Docker
usermod -aG docker ${var.vm_username}
systemctl enable docker
systemctl start docker

# kubectl
curl -L -o /tmp/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
rm -f /tmp/kubectl

# minikube
curl -Lo /tmp/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install /tmp/minikube /usr/local/bin/minikube
rm -f /tmp/minikube

# crictl (hardcoded version to avoid Terraform interpolation issues)
CRICTL_VERSION="v1.30.0"
curl -Lo /tmp/crictl-${CRICTL_VERSION}.tar.gz "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"
tar -C /usr/local/bin -xzf /tmp/crictl-${CRICTL_VERSION}.tar.gz
rm -f /tmp/crictl-${CRICTL_VERSION}.tar.gz

# cri-dockerd
git clone https://github.com/Mirantis/cri-dockerd.git /tmp/cri-dockerd
cd /tmp/cri-dockerd
make cri-dockerd || true
if [ -f cri-dockerd ]; then
  install -m 0755 cri-dockerd /usr/local/bin/cri-dockerd
  cp -r packaging/systemd/* /etc/systemd/system/ || true
  systemctl daemon-reload || true
  systemctl enable cri-docker.service || true
  systemctl start cri-docker.service || true
fi
cd /

# CNI plugins
mkdir -p /opt/cni/bin
curl -L https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz | tar -C /opt/cni/bin -xz

sync
EOT
  )
}

