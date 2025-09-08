output "aks_api_server" {
  value = try(azurerm_kubernetes_cluster.aks.kube_admin_config[0].host, "")
}

output "aks_kube_config_raw" {
  value     = try(azurerm_kubernetes_cluster.aks.kube_admin_config_raw, "")
  sensitive = true
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "aks_resource_group" {
  value = azurerm_kubernetes_cluster.aks.node_resource_group
}
