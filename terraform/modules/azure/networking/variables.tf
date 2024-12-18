variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "location" {
  type        = string
  description = "Azure Region (e.g. eastus2)"
  default     = "eastus2"
}

variable "environment" {
  type        = string
  description = "Environment identifier"
}

variable "vnet_cidr" {
  type        = string
  description = "Address space for Virtual Network"
  default     = "10.200.0.0/16"
}

variable "aks_subnet_cidr" {
  type        = string
  description = "Subnet CIDR for AKS node pools"
  default     = "10.200.1.0/24"
}

variable "ingress_subnet_cidr" {
  type        = string
  description = "Subnet CIDR for ingress and load balancers"
  default     = "10.200.2.0/24"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
