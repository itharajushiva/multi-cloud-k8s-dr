output "resource_group_name" {
  description = "The Resource Group name"
  value       = azurerm_resource_group.network.name
}

output "resource_group_location" {
  description = "The Resource Group location"
  value       = azurerm_resource_group.network.location
}

output "vnet_id" {
  description = "The VNet ID"
  value       = azurerm_virtual_network.this.id
}

output "aks_subnet_id" {
  description = "The Subnet ID allocated for AKS nodes"
  value       = azurerm_subnet.aks.id
}
