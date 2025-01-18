# Multi-Cloud Kubernetes Backup & Disaster Recovery
Automated cross-cloud failover and state replication across Amazon EKS and Microsoft Azure AKS using Terraform, Velero, and Argo CD.

---

## Architecture Overview

This project provides an active-passive disaster recovery solution between an active AWS EKS primary cluster (`us-east-1`) and an Azure AKS standby cluster (`eastus2`).

```
                        [ Global Route 53 / DNS ]
                                    |
                    +---------------+---------------+
                    | (Primary Active)              | (Standby Warm)
                    v                               v
        +-----------------------+       +-----------------------+
        |    AWS EKS Primary    |       |   Azure AKS Standby   |
        |      (us-east-1)      |       |       (eastus2)       |
        |                       |       |                       |
        | - Argo CD (Auto Sync) |       | - Argo CD (Standby)   |
        | - Velero (AWS Plugin) |       | - Velero (Multi-Cloud)|
        | - Stateful Redis App  |       | - Warm Node Pools     |
        +-----------+-----------+       +-----------+-----------+
                    |                               ^
                    | (Hourly Backup)               | (Cross-Cloud Restore)
                    v                               |
        +-----------------------+                   |
        |  AWS S3 Backup Bucket |-------------------+
        | (Kopia Engine FS/PV)  | (ReadOnly Access from AKS)
        +-----------------------+
```

### Core Components
1. **Modular Terraform**: Separated modules for `networking`, `eks` / `aks`, and `storage` for identical compute and subnet layouts across clouds.
2. **Persistent Volume Portability**: Solves AWS EBS vs. Azure Managed Disk incompatibility by utilizing Velero `node-agent` (file-system level snapshots via Kopia) and dynamic StorageClass remapping (`gp3` to `managed-csi`).
3. **Passwordless Workload Authentication**: AWS IAM Roles for Service Accounts (IRSA) and Azure Workload Identity via OIDC federation (no hardcoded static keys).
4. **GitOps via Argo CD**: ApplicationSets and Kustomize overlays managing cloud-specific ingress configurations.
5. **Automated DR Test Scripts**: Bash test harness for non-destructive restore testing, failover execution, and failback sync.

---

## Repository Structure

```text
.
|-- .github/workflows/
|   `-- ci-validation.yml         # CI pipeline for Terraform and K8s linting
|-- terraform/
|   |-- modules/
|   |   |-- aws/                  # Networking (VPC/Subnets), EKS, and S3 modules
|   |   `-- azure/                # Networking (VNet/Subnets), AKS, and Storage modules
|   `-- environments/
|       |-- aws-primary/          # Root module for AWS Primary cluster
|       `-- azure-standby/        # Root module for Azure Standby cluster
|-- velero/
|   |-- aws/                      # Velero Helm values for EKS (IRSA)
|   |-- azure/                    # Velero Helm values for AKS & storage class mapping
|   `-- schedules/                # Hourly PV and daily full cluster backup schedules
|-- workloads/guestbook/          # Sample multi-tier application (Redis leader with PV)
|-- argocd/                       # Application declarations and bootstrap script
|-- scripts/
|   |-- dr/                       # Failover, failback, and restore test scripts
|   `-- velero/                   # Velero installation and backup verification scripts
`-- docs/
    |-- architecture/             # Architecture overview and design considerations
    `-- runbooks/                 # Step-by-step Operator Failover & Failback SOP
```

---

## Deployment Steps

### 1. Provision Infrastructure with Terraform
```bash
# Provision AWS Primary Cluster
cd terraform/environments/aws-primary
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Provision Azure Standby Cluster
cd ../azure-standby
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 2. Configure Velero
```bash
# Connect to AWS EKS
aws eks update-kubeconfig --region us-east-1 --name prod-eks-primary

# Install Velero and apply schedules on AWS
./scripts/velero/install-velero.sh aws
kubectl apply -f velero/schedules/

# Connect to Azure AKS
az aks get-credentials --resource-group rg-multicloud-dr-standby-eastus2 --name standby-aks-cluster --overwrite-existing

# Install Velero on Azure
./scripts/velero/install-velero.sh azure
```

### 3. Deploy Workloads via Argo CD
```bash
# Deploy Argo CD on AWS
kubectl config use-context <AWS_EKS_CONTEXT>
./argocd/bootstrap/bootstrap-argocd.sh aws
kubectl apply -f argocd/applications/guestbook-primary.yaml
```

---

## Disaster Recovery Verification & Results

### 1. Ad-Hoc Backup with Persistent Volume State
```bash
# Set a test verification key in Redis on AWS
kubectl exec -it -n guestbook statefulset/redis-leader -- redis-cli set dr_verification_code "PASS_MULTI_CLOUD_2025"

# Trigger on-demand backup
./scripts/velero/backup-workloads.sh dr-drill-backup-01 guestbook
```

### 2. Automated Non-Destructive Restore Test
```bash
# Switch to Azure AKS
az aks get-credentials --resource-group rg-multicloud-dr-standby-eastus2 --name standby-aks-cluster --overwrite-existing

# Run restore verification script
./scripts/dr/test-dr-restore.sh dr-drill-backup-01 guestbook
```

**Verification Output:**
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
[PASS] Redis query response: "PASS_MULTI_CLOUD_2025"
============================================================
[PASS] DR Restore Test COMPLETED successfully!
 Total Recovery Time Actual (RTA): 8 minutes 42 seconds
============================================================
```

For the production emergency failover procedure, refer to the [Failover Runbook](docs/runbooks/failover-runbook.md).

---

## Security Practices Followed
* **Network Isolation**: All Kubernetes worker nodes reside in private subnets with NAT Gateway outbound routing.
* **Workload Identity**: No static cloud access keys stored in Kubernetes secrets.
* **Data Protection**: S3 server-side encryption enabled (AES256) with public access blocked; Azure Blob configured with GRS replication.
* **GitOps**: Workload deployments declarative and version-controlled via Git to eliminate configuration drift.
