output "storage_account_name" {
  description = "Velero Azure Storage Account Name"
  value       = azurerm_storage_account.velero.name
}

output "storage_container_name" {
  description = "Velero Blob Container Name"
  value       = azurerm_storage_container.velero.name
}

output "client_id" {
  description = "Client ID of the Managed Identity for Workload Identity annotation"
  value       = azurerm_user_assigned_identity.velero.client_id
}
