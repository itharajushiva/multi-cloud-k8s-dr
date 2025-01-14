# Multi-Cloud Kubernetes Disaster Recovery Architecture

## System Design & Component Overview

This architecture provides active-passive cross-cloud disaster recovery for stateful containerized workloads between **Amazon Web Services (EKS)** and **Microsoft Azure (AKS)**.

```mermaid
graph TD
    subgraph Route53 ["Global Traffic Routing"]
        DNS["Route 53 / Anycast DNS"]
    end

    subgraph AWS ["Primary Cloud: AWS (us-east-1)"]
        VPC_AWS["VPC: 10.100.0.0/16"]
        EKS["EKS Cluster: prod-eks-primary (v1.29)"]
        EBS["EBS gp3 Volumes"]
        S3["Velero S3 Bucket (AES256)"]
        ArgoAWS["Argo CD (Auto-Sync)"]
        
        VPC_AWS --> EKS
        EKS --> EBS
        EKS --> ArgoAWS
        EKS -- "Hourly Backup" --> S3
    end

    subgraph Azure ["Standby Cloud: Azure (eastus2)"]
        VNET_AZ["VNet: 10.200.0.0/16"]
        AKS["AKS Cluster: standby-aks-cluster (v1.29)"]
        ManagedDisk["Azure Managed Disks (managed-csi)"]
        Blob["Azure Storage Blob (GRS)"]
        ArgoAzure["Argo CD (GitOps Target)"]
        
        VNET_AZ --> AKS
        AKS --> ManagedDisk
        AKS --> ArgoAzure
        AKS -- "Cold/Warm Sync" --> Blob
    end

    DNS -. "Primary: 100% Traffic" .-> EKS
    DNS -. "Failover Switch" .-> AKS

    S3 -. "Cross-Cloud Backup Sync" .-> AKS
    GitRepo["GitOps Repository (Kustomize Overlays)"] --> ArgoAWS
    GitRepo --> ArgoAzure
```

## Storage Abstraction & Translation

One of the largest hurdles in cross-cloud disaster recovery is volume driver incompatibility. 

1. **StorageClass Dynamic Remapping**:
   Velero's `change-storage-class` plugin maps AWS StorageClass `gp3` directly to Azure `managed-csi` on restoration.
2. **File-System Backup (Kopia / Node-Agent)**:
   Rather than proprietary hypervisor block snapshots, Velero `node-agent` takes deduplicated, encrypted file-system level snapshots of persistent volumes directly from the pod mount points. This guarantees complete portability between AWS EBS and Azure Managed Disks.

## Network Topology & Security

- **EKS**: Private subnets across 3 Availability Zones (`us-east-1a`, `us-east-1b`, `us-east-1c`) with NAT Gateway egress and public Load Balancer subnets.
- **AKS**: Azure CNI with Calico Network Policies, isolated subnets for worker nodes and external ingress.
- **Identity & Security**:
  - AWS: IAM Roles for Service Accounts (IRSA) eliminating long-lived API keys.
  - Azure: Azure Workload Identity using OIDC federation with Azure Managed Identity.
