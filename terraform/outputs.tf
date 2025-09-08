output "aks_api_server" {
  value = azurerm_kubernetes_cluster.aks.kube_admin_config[0].host
}

output "aks_kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_admin_config[0].raw_kube_config
  sensitive = true
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "aks_resource_group" {
  value = azurerm_kubernetes_cluster.aks.node_resource_group
}
