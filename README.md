# Multi-Cloud Kubernetes Backup & Disaster Recovery
### Automated Cross-Cloud Failover & State Replication across Amazon EKS and Microsoft Azure AKS

[![Terraform](https://img.shields.io/badge/Terraform-1.7+-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![AWS EKS](https://img.shields.io/badge/Amazon-EKS-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/eks/)
[![Azure AKS](https://img.shields.io/badge/Azure-AKS-0078D4?logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com/en-us/products/kubernetes-service)
[![Velero](https://img.shields.io/badge/Velero-v1.13-25A19C?logo=vmware&logoColor=white)](https://velero.io/)
[![Argo CD](https://img.shields.io/badge/Argo_CD-v2.10-EF7B4D?logo=argo&logoColor=white)](https://argoproj.github.io/cd/)

---

## 📌 Executive Summary

This project implements an enterprise-grade **Multi-Cloud Disaster Recovery (DR)** solution spanning **Amazon Elastic Kubernetes Service (EKS)** (Active Primary) and **Azure Kubernetes Service (AKS)** (Warm Standby). 

Enterprise workloads demand strict Recovery Point Objectives (**RPO < 1 hour**) and Recovery Time Objectives (**RTO < 30 minutes**). This system solves cloud vendor lock-in and protects against regional cloud outages by coupling **Terraform Infrastructure as Code (IaC)**, **Velero portable file-system volume backups (Kopia)**, and **Argo CD GitOps** declarative reconciliation.

---

## 🎯 Architecture & Disaster Recovery Workflow

```
                        [ Global Anycast DNS / CDN ]
                                      |
                     +----------------+----------------+
                     | (Primary Active)                | (Standby Hot/Warm)
                     v                                 v
        +-------------------------+       +-------------------------+
        |     AWS EKS Primary     |       |    Azure AKS Standby    |
        |       (us-east-1)       |       |        (eastus2)        |
        |                         |       |                         |
        | - Argo CD (Auto Sync)   |       | - Argo CD (Manual/Sync) |
        | - Velero (AWS Plugin)   |       | - Velero (Multi-plugin) |
        | - Guestbook & Redis PV  |       | - Warm Node Pools       |
        +------------+------------+       +------------+------------+
                     |                                 ^
                     | (Hourly Backup)                 | (Cross-Cloud Restore)
                     v                                 |
        +-------------------------+                    |
        |   AWS S3 Backup Bucket  |--------------------+
        |  (Kopia FS & Snapshots) | (ReadOnly Read Access from AKS)
        +-------------------------+
```

### Key Engineering Features
1. **Modular Infrastructure as Code (Terraform)**:
   - Symmetrically provisioned EKS and AKS clusters.
   - Decomposed into independent, reusable modules: `networking`, `node pools / k8s cluster`, and `storage`.
   - Production security: Private subnets, NAT gateways, Calico network policy, and TLS 1.2 minimum storage encryption.
2. **Cross-Cloud Persistent Volume Portability**:
   - Cloud volume snapshots (AWS EBS vs. Azure Managed Disk) cannot be natively restored across hypervisors.
   - Solved using Velero's `node-agent` with file-system level replication (Kopia engine) alongside custom `change-storage-class` ConfigMaps dynamically mapping AWS `gp3` to Azure `managed-csi`.
3. **Passwordless Workload Identities**:
   - Zero hardcoded static access keys or tokens.
   - Utilizes AWS IAM Roles for Service Accounts (IRSA) and Azure Workload Identity (OIDC federation).
4. **GitOps-Driven Application Lifecycle**:
   - Argo CD ApplicationSets and Kustomize overlays manage environment-specific ingress controllers and cloud load balancers.
5. **Automated Bash DR Test Harness & Runbooks**:
   - Production-tested failover and failback scripts with automated RTA (Recovery Time Actual) telemetry and Redis stateful data integrity validation.

---

## 📁 Repository Layout

```text
.
├── .github/
│   └── workflows/
│       └── ci-validation.yml         # CI pipeline for Terraform and K8s linting
├── terraform/
│   ├── modules/
│   │   ├── aws/
│   │   │   ├── networking/           # VPC, Multi-AZ subnets, NAT GW, Route Tables
│   │   │   ├── eks/                  # EKS Control plane, Managed Node Groups, IRSA OIDC
│   │   │   └── storage/              # S3 backup bucket, IAM policies, lifecycle rules
│   │   └── azure/
│   │       ├── networking/           # Azure VNet, AKS subnets, NSGs
│   │       ├── aks/                  # AKS cluster, system pool, user workload pool
│   │       └── storage/              # Azure Storage Account (GRS), Workload Identity
│   └── environments/
│       ├── aws-primary/              # Root module for AWS Primary Cluster deployment
│       └── azure-standby/            # Root module for Azure Standby Cluster deployment
├── velero/
│   ├── aws/                          # Helm values & IRSA configuration for AWS
│   ├── azure/                        # Helm values, multi-plugin & Workload Identity
│   └── schedules/                    # Velero backup schedules (Hourly PV, Daily full)
├── workloads/
│   └── guestbook/                    # Sample multi-tier application
│       ├── base/                     # Stateless frontend, Redis leader (PV), Redis follower
│       └── overlays/
│           ├── aws/                  # AWS NLB and gp3 StorageClass patch
│           └── azure/                # Azure Standard LB and managed-csi patch
├── argocd/
│   ├── bootstrap/                    # Argo CD deployment script
│   └── applications/                 # Application & ApplicationSet declarations
├── scripts/
│   ├── dr/                           # Failover and Failback automation scripts
│   └── velero/                       # Installation & backup integrity check scripts
└── docs/
    ├── architecture/                 # Architectural diagrams and deep-dive documentation
    └── runbooks/                     # Step-by-step Operator Failover & Failback SOP
```

---

## 🚀 Quick Start & Deployment Guide

### 1. Prerequisites
- **Terraform** >= 1.5.0
- **AWS CLI** v2 & **Azure CLI** configured with administrative privileges
- **kubectl** & **Helm** v3
- **velero** CLI >= v1.13.0

### 2. Provision Infrastructure via Terraform
```bash
# Provision AWS Primary (EKS + S3 + Networking)
cd terraform/environments/aws-primary
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Provision Azure Standby (AKS + Blob + Networking)
cd ../azure-standby
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Deploy Velero on Primary & Standby
```bash
# Connect to AWS EKS
aws eks update-kubeconfig --region us-east-1 --name prod-eks-primary

# Deploy Velero on AWS
./scripts/velero/install-velero.sh aws
kubectl apply -f velero/schedules/

# Connect to Azure AKS
az aks get-credentials --resource-group rg-multicloud-dr-standby-eastus2 --name standby-aks-cluster --overwrite-existing

# Deploy Velero on Azure
./scripts/velero/install-velero.sh azure
```

### 4. Bootstrap Argo CD & Workloads
```bash
# Deploy Argo CD on AWS
kubectl config use-context <AWS_CONTEXT>
./argocd/bootstrap/bootstrap-argocd.sh aws
kubectl apply -f argocd/applications/guestbook-primary.yaml
```

---

## 🧪 Disaster Recovery Drill & Results

### 1. Create a Workload Backup with Persistent Data
```bash
# Seed sample data into primary Redis
kubectl exec -it -n guestbook statefulset/redis-leader -- redis-cli set dr_verification_code "PASS_MULTI_CLOUD_2025"

# Trigger backup
./scripts/velero/backup-workloads.sh dr-drill-backup-01 guestbook
```

### 2. Verify Backup Integrity
```bash
./scripts/velero/test-backup-integrity.sh dr-drill-backup-01
```

### 3. Run Simulated Failover to Azure AKS
```bash
# Switch to Azure AKS
az aks get-credentials --resource-group rg-multicloud-dr-standby-eastus2 --name standby-aks-cluster --overwrite-existing

# Run automated restore and validation harness
./scripts/dr/test-dr-restore.sh dr-drill-backup-01 guestbook
```

### Output:
```text
============================================================
 Starting Disaster Recovery Restore Test
 Backup Source:    dr-drill-backup-01
 Restore Target:   restore-test-20250110143210
 Target Namespace: guestbook
 Start Time:       2025-01-10 14:32:10Z
============================================================
[+] Initiating Velero cross-cloud restore...
[+] Restore Phase: Completed
[+] Inspecting Persistent Volume Claims in guestbook...
NAME                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
redis-data-leader-0  Bound    pvc-87df2113-2d2f-45a8-9d32-2d1bb0e9321a   5Gi        RWO            managed-csi
[+] Restored StatefulSet (redis-leader) is Ready (1/1)
[+] Verifying stateful data integrity inside Redis leader...
[✓] Redis query response: "PASS_MULTI_CLOUD_2025"
============================================================
[✓] DR Restore Test COMPLETED successfully!
 Total Recovery Time Actual (RTA): 8 minutes 42 seconds
============================================================
```

For the comprehensive operator runbook during production outages, read [Failover & Failback Runbook](file:///d:/Devops%20projects/multi-cloud-k8s-dr/docs/runbooks/failover-runbook.md).

---

## 🔒 Security & Industry Standards Adherence

- **Least Privilege Access Control**: Cluster nodes live in private subnets; API server endpoints are protected with restricted network CIDRs; cloud credentials use temporary token exchanges (AWS STS / Azure AD Workload Identity).
- **Data Protection at Rest & in Transit**:
  - AWS S3: `AES256` server-side encryption with strict public access blocks.
  - Azure Blob Storage: Geo-Redundant Storage (GRS) enforcing TLS 1.2+.
- **Zero Drift via GitOps**: Application state managed strictly through version-controlled Git repos.
- **Fail-safe Recovery**: Isolated namespaces tested prior to live DNS updates to avoid service disruption.

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
