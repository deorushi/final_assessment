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

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "ci-cd-aks"
  location            = azurerm_resource_group.ci_cd_rg.location
  resource_group_name = azurerm_resource_group.ci_cd_rg.name
  dns_prefix          = "ci-cd-aks"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    dns_service_ip    = "10.2.0.10"
    service_cidr      = "10.2.0.0/24"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  role_based_access_control {
    enabled = true
  }

  linux_profile {
    admin_username = var.vm_username

    ssh_key {
      key_data = file("${path.module}/ci_cd_key.pub")
    }
  }

  tags = {
    environment = "ci-cd"
  }
}

# Output kubeconfig for GitHub Actions
output "kubeconfig" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}
