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

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOT
#!/bin/bash
# Update system
apt-get update -y
apt-get install -y docker.io curl conntrack socat tar git build-essential golang-go make sshpass conntrack iproute2

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

# Install cri-dockerd
git clone https://github.com/Mirantis/cri-dockerd.git /tmp/cri-dockerd
cd /tmp/cri-dockerd
make cri-dockerd
install cri-dockerd /usr/local/bin/
cp packaging/systemd/* /etc/systemd/system/
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl start cri-docker.service

# Install CNI plugins
mkdir -p /opt/cni/bin
curl -L https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz | tar -C /opt/cni/bin -xz

EOT
  )
}
