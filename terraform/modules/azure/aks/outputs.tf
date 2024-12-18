output "cluster_name" {
  description = "The name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "The ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.id
}

output "kube_config_raw" {
  description = "Raw Kubernetes config for cluster connection"
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "cluster_endpoint" {
  description = "The Kubernetes API server host"
  value       = azurerm_kubernetes_cluster.this.kube_config[0].host
}

output "oidc_issuer_url" {
  description = "OIDC Issuer URL for Azure Workload Identity"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "node_resource_group" {
  description = "The auto-generated Resource Group containing node infrastructure"
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}
