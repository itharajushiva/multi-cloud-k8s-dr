output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_cluster_endpoint" {
  value = module.aks.cluster_endpoint
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "velero_storage_account" {
  value = module.storage.storage_account_name
}

output "velero_container_name" {
  value = module.storage.storage_container_name
}

output "velero_managed_client_id" {
  value = module.storage.client_id
}

output "configure_kubectl_command" {
  value = "az aks get-credentials --resource-group ${var.resource_group_name} --name ${module.aks.cluster_name} --overwrite-existing"
}
