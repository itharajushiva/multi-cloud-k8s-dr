variable "cluster_name" {
  type        = string
  description = "AKS Cluster name"
}

variable "resource_group_name" {
  type        = string
  description = "Target Resource Group Name"
}

variable "location" {
  type        = string
  description = "Azure Region"
}

variable "environment" {
  type        = string
  description = "Environment identifier"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes Version (matches EKS 1.29)"
  default     = "1.29.2"
}

variable "vnet_subnet_id" {
  type        = string
  description = "Subnet ID for AKS Nodes"
}

variable "system_node_count" {
  type        = number
  description = "Number of system nodes"
  default     = 2
}

variable "system_vm_size" {
  type        = string
  description = "VM size for system nodes"
  default     = "Standard_D2s_v5"
}

variable "workload_vm_size" {
  type        = string
  description = "VM size for worker workloads (4 vCPU, 16GB RAM matching t3.xlarge)"
  default     = "Standard_D4s_v5"
}

variable "desired_workload_count" {
  type        = number
  description = "Initial worker node count"
  default     = 3
}

variable "min_workload_count" {
  type        = number
  description = "Min worker node count"
  default     = 2
}

variable "max_workload_count" {
  type        = number
  description = "Max worker node count"
  default     = 6
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
