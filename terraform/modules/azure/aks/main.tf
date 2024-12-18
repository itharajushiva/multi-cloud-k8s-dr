# Azure Managed Kubernetes (AKS) Cluster matching EKS configurations

resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.cluster_name}-control-plane-identity"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

# AKS Cluster Control Plane
resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.cluster_name}-dns"
  kubernetes_version  = var.kubernetes_version

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # System Node Pool (Equivalent to EKS core workloads)
  default_node_pool {
    name                = "syspool"
    node_count          = var.system_node_count
    vm_size             = var.system_vm_size
    vnet_subnet_id      = var.vnet_subnet_id
    os_disk_size_gb     = 50
    os_disk_type        = "Managed"
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = false

    node_labels = {
      "role" = "system"
    }

    tags = var.tags
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"
    dns_service_ip     = "10.0.0.10"
    service_cidr       = "10.0.0.0/16"
    docker_bridge_cidr = "172.17.0.1/16"
    load_balancer_sku  = "standard"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = var.tags
}

# Dedicated User Node Pool (Matching EKS t3.xlarge worker capacity)
resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "workloadpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.workload_vm_size
  vnet_subnet_id        = var.vnet_subnet_id
  os_disk_size_gb       = 100
  enable_auto_scaling   = true
  min_count             = var.min_workload_count
  max_count             = var.max_workload_count
  node_count            = var.desired_workload_count

  node_labels = {
    "role"        = "worker"
    "environment" = var.environment
  }

  tags = var.tags
}
