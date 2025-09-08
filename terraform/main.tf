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
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
  }

  tags = {
    environment = "ci-cd"
  }
}
