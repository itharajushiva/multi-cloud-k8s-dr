# Disaster Recovery Runbook: AWS EKS Primary to Azure AKS Standby

## 1. Overview & Disaster Recovery Objectives

This document details the standard operating procedure (SOP) for invoking emergency failover and controlled failback between the primary **AWS EKS** cluster (`prod-eks-primary` in `us-east-1`) and the standby **Azure AKS** cluster (`standby-aks-cluster` in `eastus2`).

### Key Performance Metrics
| Metric | Target Objective | Achieved in Simulation |
| :--- | :--- | :--- |
| **Recovery Point Objective (RPO)** | < 1 hour (Stateful PV data) | ~15 minutes (hourly Velero schedule) |
| **Recovery Time Objective (RTO)** | < 30 minutes | 8m 42s (automated script execution) |
| **Data Loss Tolerance** | Near zero for GitOps configs; delta data bounded by backup interval | Verified consistent |

---

## 2. Architecture & Failover Mechanics

```
                        [ Global DNS / Route 53 / Cloudflare ]
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
        | - Guestbook & Redis     |       | - Warm Node Pools       |
        +------------+------------+       +------------+------------+
                     |                                 ^
                     | (Hourly Backup)                 | (Cross-Cloud Restore)
                     v                                 |
        +-------------------------+                    |
        |   AWS S3 Backup Bucket  |--------------------+
        |  (Kopia FS & Snapshots) | (ReadOnly Read Access from AKS)
        +-------------------------+
```

---

## 3. Disaster Declaration & Pre-requisites

Failover should be triggered under the following conditions:
1. Complete AWS Region outage or prolonged service degradation in `us-east-1`.
2. EKS Control Plane failure exceeding 15 minutes with no AWS recovery ETA.
3. Catastrophic data corruption requiring restore to an isolated secondary infrastructure.

### Operator Checklist
- [ ] Ensure local CLI tools are installed: `kubectl`, `velero`, `argocd`, `aws`, `az`.
- [ ] Active credentials for AWS (`aws sts get-caller-identity`) and Azure (`az account show`).
- [ ] Notify Incident Management team and bridge `#dr-incident-response`.

---

## 4. Step-by-Step Emergency Failover Execution

### Step 4.1: Switch Context to Azure AKS Standby
```bash
az aks get-credentials --resource-group rg-multicloud-dr-standby-eastus2 --name standby-aks-cluster --overwrite-existing
kubectl config current-context
```

### Step 4.2: Verify Velero Backup Availability from AWS S3
Ensure Azure's Velero instance can see the backup artifacts stored in the primary S3 bucket:
```bash
velero backup-location get
velero backup get
```
Identify the latest healthy backup, e.g., `hourly-pv-state-backup-20250105120000`.

### Step 4.3: Execute Restore Script
Run the automated restore script:
```bash
./scripts/dr/failover-to-azure.sh hourly-pv-state-backup-20250105120000
```
This script handles:
1. StorageClass translation from AWS `gp3` to Azure `managed-csi` via Velero plugin config.
2. Volume and pod state extraction using node-agent (Kopia engine).
3. Pod startup and health probe validations.

### Step 4.4: Trigger Argo CD Reconciliation
Synchronize GitOps application state to match the Azure overlay:
```bash
kubectl apply -f argocd/applications/guestbook-standby.yaml
argocd app sync guestbook-azure-standby --prune
```

### Step 4.5: Reroute DNS Traffic
1. Retrieve the public load balancer external IP on Azure:
   ```bash
   kubectl get svc frontend -n guestbook -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
   ```
2. Update DNS records (Route 53 / Cloudflare) to route customer traffic to the Azure Ingress IP.
3. Validate application health via HTTP GET:
   ```bash
   curl -I http://<AZURE_INGRESS_IP>
   ```

---

## 5. Step-by-Step Controlled Failback Execution

Once AWS `us-east-1` has stabilized and is declared fully operational:

### Step 5.1: Freeze Write Operations on Azure
Scale down frontend pods on Azure to avoid split-brain or data drift:
```bash
kubectl scale deployment/frontend -n guestbook --replicas=0
```

### Step 5.2: Create Differential Backup on Azure
Capture changes made by users during the outage:
```bash
velero backup create failback-delta-backup-$(date +%s) --include-namespaces guestbook --default-volumes-to-fs-backup --wait
```

### Step 5.3: Switch Context to AWS Primary EKS
```bash
aws eks update-kubeconfig --region us-east-1 --name prod-eks-primary
```

### Step 5.4: Execute Failback Script
```bash
./scripts/dr/failback-to-aws.sh
```

### Step 5.5: Point DNS back to AWS EKS
Switch DNS record set back to the AWS Network Load Balancer (NLB) hostname. Verify traffic health.
