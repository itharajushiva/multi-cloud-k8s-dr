# Azure Storage Account and Blob Container for Velero Backups

resource "azurerm_storage_account" "velero" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS" # Geo-Redundant Storage for true DR
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = merge(
    var.tags,
    {
      Purpose = "Velero AKS Disaster Recovery"
    }
  )
}

resource "azurerm_storage_container" "velero" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.velero.name
  container_access_type = "private"
}

# User Assigned Managed Identity for Velero AKS
resource "azurerm_user_assigned_identity" "velero" {
  name                = "${var.cluster_name}-velero-identity"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

# Federated Identity Credential linking AKS ServiceAccount to Azure Managed Identity
resource "azurerm_federated_identity_credential" "velero" {
  name                = "${var.cluster_name}-velero-fed-credential"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.velero.id
  subject             = "system:serviceaccount:velero:velero-server"
}

# Role assignment allowing Velero to manage Storage Account Blob Data
resource "azurerm_role_assignment" "velero_blob_contributor" {
  scope                = azurerm_storage_account.velero.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.velero.principal_id
}

# Role assignment allowing Velero snapshot disk operations on the node resource group
resource "azurerm_role_assignment" "velero_disk_contributor" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.node_resource_group}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.velero.principal_id
}
