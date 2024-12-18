variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "resource_group_name" {
  type        = string
  description = "Resource Group Name for AKS Standby environment"
  default     = "rg-multicloud-dr-standby-eastus2"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "eastus2"
}

variable "environment" {
  type        = string
  default     = "dr-standby"
}

variable "cluster_name" {
  type        = string
  default     = "standby-aks-cluster"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.29.2"
}

variable "vnet_cidr" {
  type        = string
  default     = "10.200.0.0/16"
}

variable "aks_subnet_cidr" {
  type        = string
  default     = "10.200.1.0/24"
}

variable "ingress_subnet_cidr" {
  type        = string
  default     = "10.200.2.0/24"
}

variable "system_node_count" {
  type        = number
  default     = 2
}

variable "system_vm_size" {
  type        = string
  default     = "Standard_D2s_v5"
}

variable "workload_vm_size" {
  type        = string
  default     = "Standard_D4s_v5"
}

variable "desired_workload_count" {
  type        = number
  default     = 3
}

variable "min_workload_count" {
  type        = number
  default     = 2
}

variable "max_workload_count" {
  type        = number
  default     = 6
}

variable "storage_account_name" {
  type        = string
  description = "Unique Azure Storage account for standby backups (alphanumeric lowercase, 3-24 chars)"
  default     = "stvelerodrstandby2910"
}

variable "container_name" {
  type        = string
  default     = "velero-backups"
}

variable "tags" {
  type        = map(string)
  default = {
    Project     = "multi-cloud-k8s-dr"
    Environment = "dr-standby"
    Provider    = "Azure"
    Role        = "Standby-DR-Cluster"
  }
}
