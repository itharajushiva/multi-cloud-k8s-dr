terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90.0"
    }
  }

  # Production best practice: remote state in Azure Blob Storage
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "tfstatedrstandby"
  #   container_name       = "tfstate"
  #   key                  = "azure-standby/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

# Module: Azure Virtual Network & Subnets
module "networking" {
  source = "../../modules/azure/networking"

  resource_group_name = var.resource_group_name
  location            = var.location
  environment         = var.environment
  vnet_cidr           = var.vnet_cidr
  aks_subnet_cidr     = var.aks_subnet_cidr
  ingress_subnet_cidr = var.ingress_subnet_cidr
  tags                = var.tags
}

# Module: AKS Cluster & User Workload Pool
module "aks" {
  source = "../../modules/azure/aks"

  cluster_name           = var.cluster_name
  resource_group_name    = module.networking.resource_group_name
  location               = module.networking.resource_group_location
  environment            = var.environment
  kubernetes_version     = var.kubernetes_version
  vnet_subnet_id         = module.networking.aks_subnet_id
  system_node_count      = var.system_node_count
  system_vm_size         = var.system_vm_size
  workload_vm_size       = var.workload_vm_size
  desired_workload_count = var.desired_workload_count
  min_workload_count     = var.min_workload_count
  max_workload_count     = var.max_workload_count
  tags                   = var.tags
}

# Module: Blob Storage & Workload Identity for Velero DR
module "storage" {
  source = "../../modules/azure/storage"

  resource_group_name  = module.networking.resource_group_name
  location             = module.networking.resource_group_location
  storage_account_name = var.storage_account_name
  container_name       = var.container_name
  cluster_name         = var.cluster_name
  oidc_issuer_url      = module.aks.oidc_issuer_url
  subscription_id      = var.subscription_id
  node_resource_group  = module.aks.node_resource_group
  tags                 = var.tags
}
