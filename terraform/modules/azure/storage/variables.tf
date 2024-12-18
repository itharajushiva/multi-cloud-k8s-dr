variable "resource_group_name" {
  type        = string
  description = "Resource Group Name"
}

variable "location" {
  type        = string
  description = "Azure Region"
}

variable "storage_account_name" {
  type        = string
  description = "Unique Azure Storage Account name (lowercase, alphanumeric, 3-24 chars)"
}

variable "container_name" {
  type        = string
  description = "Blob container name for backups"
  default     = "velero-backups"
}

variable "cluster_name" {
  type        = string
  description = "AKS Cluster Name"
}

variable "oidc_issuer_url" {
  type        = string
  description = "AKS OIDC Issuer URL for workload identity federation"
}

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "node_resource_group" {
  type        = string
  description = "Node Resource Group name where persistent disks are provisioned"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
