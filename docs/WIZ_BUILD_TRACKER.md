# WIZ Technical Exercise - Build Tracker

**Candidate:** Tem Muya Tiagha
**Date Started:** January 2026
**AWS Account:** 504784824189
**Region:** us-east-1
**GitHub:** https://github.com/TTiagha/wiz-technical-exercise

---

## Document Structure

This tracker is organized into **three sequential phases**:

| Phase Group | Phases | Purpose |
|-------------|--------|---------|
| **Core Infrastructure** | 1-6 | Build the vulnerable environment |
| **Core Validation** | 7A | Verify Phases 1-6 work correctly |
| **Security Layer** | 8-9 | Add detection & remediation docs |
| **Security Validation** | 7B | Verify Phases 8-9 work correctly |
| **CI/CD** | 10 | Pipeline automation (optional) |

**Execution Order:** 1 → 2 → 3 → 4 → 5 → 6 → 7A → 8 → 9 → 7B → 10

---

## Pre-Flight Checklist

- [x] AWS CLI configured and working
- [x] Terraform installed (v1.7.0+)
- [x] Docker installed
- [x] kubectl installed
- [x] eksctl installed

---

## Phase 1: VPC Infrastructure

**Depends on:** Pre-flight checklist
**Creates foundation for:** All subsequent phases

### What We Created
| Resource | Purpose | CIDR/Config | Actual ID |
|----------|---------|-------------|-----------|
| VPC | Main network container | 10.0.0.0/16 | vpc-08822ec17a8c3a636 |
| Public Subnet 1 | MongoDB, NAT GW | 10.0.1.0/24 | (in VPC) |
| Public Subnet 2 | ALB (HA) | 10.0.2.0/24 | (in VPC) |
| Private Subnet 1 | EKS nodes | 10.0.101.0/24 | (in VPC) |
| Private Subnet 2 | EKS nodes (HA) | 10.0.102.0/24 | (in VPC) |
| Internet Gateway | Public internet access | N/A | (attached to VPC) |
| NAT Gateway | Private subnet outbound | In public-1 | (in VPC) |

### Terraform State
- **State file:** `terraform/terraform.tfstate`
- **Total resources:** 46

### Resources Created
- [x] VPC: vpc-08822ec17a8c3a636
- [x] Public Subnets: 2 created
- [x] Private Subnets: 2 created
- [x] Internet Gateway: attached
- [x] NAT Gateway: created

---

## Phase 2: Security Groups

**Depends on:** Phase 1 (VPC)
**Creates:** Network access rules with intentional weakness

### Security Group Configuration
| SG Name | Port | Source | Weakness? |
|---------|------|--------|-----------|
| wiz-exercise-mongo-sg | 22 (SSH) | 0.0.0.0/0 | **YES - INTENTIONAL** |
| wiz-exercise-mongo-sg | 27017 | VPC only | No (correct) |
| wiz-exercise-eks-sg | All | Self | No |
| wiz-exercise-alb-sg | 80, 443 | 0.0.0.0/0 | No (expected for ALB) |

### Security Finding #1: SSH Exposed to Internet
- **Severity (Isolated):** MEDIUM - Enables brute-force attempts
- **Severity (Chained):** CRITICAL - Combines with outdated OS + overpermissive IAM

---

## Phase 3: MongoDB VM

**Depends on:** Phase 1 (VPC), Phase 2 (Security Groups)
**Creates:** Database tier with multiple intentional weaknesses

### Instance Details
| Property | Value |
|----------|-------|
| AMI | Ubuntu 20.04 LTS (focal) |
| Instance Type | t3.small |
| Public IP | 50.17.254.246 |
| Private IP | 10.0.1.208 |
| Subnet | Public (intentional weakness) |
| Security Group | wiz-exercise-mongo-sg |
| IAM Role | wiz-exercise-mongodb-role |
| SSH Key | mongodb-key.pem (in terraform/) |

### MongoDB Version
- **Version:** 4.4.29 (EOL Feb 2024)
- **Why Outdated:** Exercise requirement - 1+ year old

### Security Finding #2: Outdated Software
- **Ubuntu 20.04:** Known kernel CVEs available
- **MongoDB 4.4:** End-of-life, no security patches

### Security Finding #3: Overpermissive IAM Role
```json
{
  "Effect": "Allow",
  "Action": ["ec2:*", "s3:*"],
  "Resource": "*"
}
```
- **Severity (Isolated):** HIGH - Violates least privilege
- **Severity (Chained):** CRITICAL - VM compromise = AWS account compromise

### Verification
```bash
# SSH to MongoDB VM
ssh -i terraform/mongodb-key.pem ubuntu@50.17.254.246

# Check MongoDB status
sudo systemctl status mongod

# Verify MongoDB version
mongod --version  # Should show 4.4.x

# Test connection
mongosh -u admin -p 'PASSWORD' --authenticationDatabase admin
```

---

## Phase 4: S3 Bucket (PUBLIC)

**Depends on:** Phase 3 (MongoDB for backups)
**Creates:** Backup storage with critical intentional weakness

### Bucket Configuration
| Property | Value |
|----------|-------|
| Bucket Name | wiz-exercise-backups-bfde675c |
| Public Access | **ENABLED (intentional weakness)** |
| Contents | MongoDB backup archives |
| Backup Schedule | Daily cron job on MongoDB VM |

### Security Finding #4: Public S3 Bucket with Sensitive Data
- **Severity (Isolated):** CRITICAL - No exploitation required
- **Severity (Chained):** CATASTROPHIC - Contains DB credentials

### Verification
```bash
# Prove bucket is public (no authentication!)
aws s3 ls s3://wiz-exercise-backups-bfde675c/ --no-sign-request

# Download backup without auth
curl -O https://wiz-exercise-backups-bfde675c.s3.amazonaws.com/backups/latest.archive
```

---

## Phase 5: EKS Cluster

**Depends on:** Phase 1 (VPC - private subnets)
**Creates:** Kubernetes cluster (correctly in private subnets)

### Cluster Configuration
| Property | Value |
|----------|-------|
| Cluster Name | wiz-exercise |
| K8s Version | 1.28 |
| Subnets | Private (correct!) |
| Node Type | t3.medium |
| Node Count | 2 |

### Verification
```bash
# Configure kubectl
aws eks update-kubeconfig --name wiz-exercise --region us-east-1

# Verify nodes
kubectl get nodes
# Should show 2 Ready nodes
```

---

## Phase 6: Container Deployment

**Depends on:** Phase 5 (EKS), Phase 3 (MongoDB for connection)
**Creates:** Application with RBAC weakness

### Image Details
| Property | Value |
|----------|-------|
| Registry | 504784824189.dkr.ecr.us-east-1.amazonaws.com |
| Repository | wiz-exercise-todo-app |
| wizexercise.txt | Contains "Tem Muya Tiagha" |

### Kubernetes Resources
| Resource | Name | Config |
|----------|------|--------|
| Namespace | todo-app | - |
| Deployment | todo-app | 2 replicas |
| Service | todo-app-service | ClusterIP |
| Ingress | todo-app-ingress | ALB |
| ServiceAccount | todo-app-sa | **cluster-admin (weakness!)** |

### ALB Endpoint
```
http://a60274b82250e4931b580f0e5abb694b-1866901723.us-east-1.elb.amazonaws.com
```

### Security Finding #5: cluster-admin on Application
- **Severity (Isolated):** HIGH - App can read all secrets
- **Severity (Chained):** CRITICAL - Any app vuln = full cluster compromise

### Verification
```bash
# Check pods
kubectl get pods -n todo-app

# Verify wizexercise.txt
kubectl exec $(kubectl get pods -n todo-app -l app=todo-app -o jsonpath='{.items[0].metadata.name}') \
  -n todo-app -- cat /app/wizexercise.txt
# Should output: Tem Muya Tiagha

# Prove cluster-admin (the weakness)
kubectl auth can-i --list --as=system:serviceaccount:todo-app:todo-app-sa
# Shows full cluster access
```

---

## Phase 7A: Core Infrastructure Validation

**Validates:** Phases 1-6
**Run BEFORE:** Phase 8

### Infrastructure Checklist
- [x] VPC created with 4 subnets (vpc-08822ec17a8c3a636)
- [x] MongoDB VM running at 50.17.254.246
- [x] MongoDB 4.4 accepting connections
- [x] S3 bucket publicly accessible (wiz-exercise-backups-bfde675c)

### Application Checklist
- [x] Container image in ECR
- [x] wizexercise.txt contains "Tem Muya Tiagha"
- [x] App deployed with 2 replicas
- [x] ALB accessible at endpoint above
- [x] Can CRUD todos via UI

### Security Findings Present (Intentional)
| # | Finding | Status |
|---|---------|--------|
| 1 | SSH exposed to 0.0.0.0/0 | [x] Verified |
| 2 | Ubuntu 20.04 (outdated) | [x] Verified |
| 3 | MongoDB 4.4 (EOL) | [x] Verified |
| 4 | IAM role with ec2:*, s3:* | [x] Verified |
| 5 | S3 bucket is public | [x] Verified |
| 6 | cluster-admin on app SA | [x] Verified |

**Status:** All core infrastructure complete. Proceed to Phase 8.

---

## Phase 8: AWS Native Security Controls

**Depends on:** Phase 7A complete (infrastructure must exist to detect)
**Creates:** Detection capabilities that find our intentional weaknesses

### Purpose
Deploy AWS native security tools to demonstrate:
1. What they CAN detect (our misconfigurations)
2. What they CAN'T provide (attack path context - Wiz's value)

### What We Deploy
| Control | Type | Purpose | What It Detects |
|---------|------|---------|-----------------|
| CloudTrail | Audit | Logs all API calls | Reactive - after actions occur |
| AWS Config | Detective | Evaluates compliance | Public S3, SSH exposure |
| GuardDuty | Detective | Threat detection | Anomalous activity |

### Terraform File
- **File:** `terraform/security_controls.tf`
- **Resources:** CloudTrail, Config recorder, 2 Config rules, GuardDuty detector

### Config Rules Deployed
| Rule Name | AWS Identifier | Detects |
|-----------|----------------|---------|
| s3-bucket-public-read-prohibited | S3_BUCKET_PUBLIC_READ_PROHIBITED | Our public backup bucket |
| restricted-ssh | INCOMING_SSH_DISABLED | Our SSH 0.0.0.0/0 rule |

### Deploy Commands
```bash
cd terraform
terraform plan   # Review changes
terraform apply  # Deploy security controls
```

---

## Phase 9: Security Remediation (Documentation Only)

**Depends on:** Phase 8 (understand what native tools detect)
**Creates:** Secure config files for before/after comparison

### Purpose
Create "secure" versions of our vulnerable configs. These are **NOT deployed** - they're documentation for the interview to show remediation knowledge.

### Files to Create
| File | Location | What It Fixes |
|------|----------|---------------|
| s3_secure.tf | terraform/secure/ | Private bucket, encryption, specific IAM |
| security_groups_secure.tf | terraform/secure/ | SSH restricted to VPN CIDR |
| iam_secure.tf | terraform/secure/ | Least-privilege (s3:PutObject only) |
| k8s_rbac_secure.yaml | terraform/secure/ | Role instead of ClusterRole |

### Before/After Summary
| Finding | Vulnerable | Remediated |
|---------|------------|------------|
| SSH | `0.0.0.0/0` | `10.0.0.0/8` (VPN only) |
| S3 | `Principal: "*"` | `Principal: specific-role-arn` |
| IAM | `ec2:*, s3:*` | `s3:PutObject` on one bucket |
| K8s | `cluster-admin` | `Role: get mongo-credentials secret` |

---

## Phase 7B: Security Layer Validation

**Validates:** Phases 8-9
**Run AFTER:** Phases 8-9 deployed/created

### AWS Security Controls
| Control | Verification Command | Expected Result |
|---------|---------------------|-----------------|
| CloudTrail | `aws cloudtrail get-trail-status --name wiz-exercise-trail --query 'IsLogging'` | `true` |
| Config (S3) | `aws configservice get-compliance-details-by-config-rule --config-rule-name s3-bucket-public-read-prohibited --compliance-types NON_COMPLIANT` | Shows our bucket |
| Config (SSH) | `aws configservice get-compliance-details-by-config-rule --config-rule-name restricted-ssh --compliance-types NON_COMPLIANT` | Shows our SG |
| GuardDuty | `aws guardduty list-detectors` | Returns detector ID |

### Security Controls Checklist
- [ ] CloudTrail shows `IsLogging: true`
- [ ] Config flags S3 bucket as NON_COMPLIANT
- [ ] Config flags security group as NON_COMPLIANT
- [ ] GuardDuty detector is ENABLED

### Secure Configs (Documentation)
- [ ] terraform/secure/s3_secure.tf created
- [ ] terraform/secure/security_groups_secure.tf created
- [ ] terraform/secure/iam_secure.tf created
- [ ] terraform/secure/k8s_rbac_secure.yaml created

---

## Phase 10: CI/CD Pipeline (Optional)

**Depends on:** All infrastructure phases
**Creates:** Automated deployment and security scanning

### GitHub Repository
- **URL:** https://github.com/TTiagha/wiz-technical-exercise
- **Pipelines:** GitHub Actions

### Workflows
| Workflow | Trigger | Purpose |
|----------|---------|---------|
| infra-deploy.yml | Push to terraform/ | Plan and apply infrastructure |
| app-build-deploy.yml | Push to app/ | Build, scan, push, deploy |

### Security Scanning
- **Trivy:** Container image vulnerability scanning
- **tfsec:** Terraform security scanning (will flag our intentional weaknesses)

---

## Security Findings Summary

### The Six Intentional Weaknesses

| # | Finding | Location | Isolated Severity | Chained Severity |
|---|---------|----------|-------------------|------------------|
| 1 | SSH 0.0.0.0/0 | Security Group | MEDIUM | CRITICAL |
| 2 | Ubuntu 20.04 | MongoDB VM | MEDIUM | HIGH |
| 3 | MongoDB 4.4 EOL | MongoDB VM | MEDIUM | HIGH |
| 4 | IAM ec2:*, s3:* | MongoDB VM Role | HIGH | CRITICAL |
| 5 | Public S3 | Backup Bucket | CRITICAL | CATASTROPHIC |
| 6 | cluster-admin | K8s ServiceAccount | HIGH | CRITICAL |

### Three Attack Paths

**Path 1: MongoDB VM Entry**
```
Internet → SSH (0.0.0.0/0) → Ubuntu Exploit → Root → IAM Role → AWS Account
```

**Path 2: Kubernetes App Entry**
```
Internet → ALB → App Vulnerability → Pod → cluster-admin → All Secrets → Database
```

**Path 3: Public S3 (No Exploitation Required!)**
```
Internet → S3 Public Access → Download Backup → Extract Credentials → Direct DB Access
```

### AWS Config Detection vs Wiz Value

| What Config Says | What Wiz Adds |
|------------------|---------------|
| "S3 bucket is public" | "...and contains database backups with MongoDB credentials" |
| "SSH allows 0.0.0.0/0" | "...which chains to outdated Ubuntu + overpermissive IAM = account takeover" |
| "NON_COMPLIANT" | "Attack path with 3 hops to data exfiltration" |

---

## Interview Talking Points (Consolidated)

### On Architecture Decisions
> "Public subnets have routes to the Internet Gateway for inbound connections. Private subnets use NAT Gateway for outbound-only. MongoDB is intentionally in public - that's one of our findings."

### On CIDR 0.0.0.0/0
> "The /0 means zero bits are fixed, so all 32 bits can vary - every IP from 0.0.0.0 to 255.255.255.255. It means 'allow from anywhere on the internet.'"

### On Chained vs Isolated Risk
> "SSH exposed by itself is MEDIUM - enables brute-force. But combined with outdated Ubuntu and overpermissive IAM, it becomes a path to full account compromise. Same finding, different severity based on context."

### On Public S3
> "This is CRITICAL even in isolation. No exploitation required - anyone with a browser can download our database backups, extract credentials, and access production data."

### On cluster-admin
> "If our app has ANY vulnerability - SSRF, RCE, Log4Shell - the attacker immediately has full cluster access. They can read every secret, deploy malware, or ransom the cluster."

### On AWS Config vs Wiz
> "Config tells me WHAT is wrong - 'bucket is public.' Wiz tells me WHY it matters - 'bucket contains database backups with credentials that give access to production data with customer PII.' Same finding, completely different business impact."

### On Remediation Priority
> "I prioritize by attack path severity, not individual finding severity. Fix public S3 first - no exploit needed. Then restrict SSH. Then reduce IAM blast radius. Then K8s RBAC as defense in depth."

---

## Teardown Commands

**Important:** Run in this order to avoid orphaned resources.

```bash
# 1. Delete Kubernetes resources first
kubectl delete namespace todo-app

# 2. Wait for ALB to be deleted (created by ingress)
# Check: aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'wiz')]"

# 3. Delete EKS node group (takes ~5-10 minutes)
aws eks delete-nodegroup --cluster-name wiz-exercise --nodegroup-name wiz-exercise-nodes
aws eks wait nodegroup-deleted --cluster-name wiz-exercise --nodegroup-name wiz-exercise-nodes

# 4. Delete EKS cluster (takes ~10 minutes)
aws eks delete-cluster --name wiz-exercise
aws eks wait cluster-deleted --name wiz-exercise

# 5. Terraform destroy (handles VPC, EC2, S3, security controls)
cd terraform
terraform destroy -auto-approve

# 6. Verify cleanup
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=wiz-technical-exercise"
# Should return empty

# 7. Delete ECR images (optional - costs minimal)
aws ecr batch-delete-image --repository-name wiz-exercise-todo-app --image-ids imageTag=latest
```

---

## Current Infrastructure State

| Resource | Value |
|----------|-------|
| VPC | vpc-08822ec17a8c3a636 |
| MongoDB VM (Public) | 50.17.254.246 |
| MongoDB VM (Private) | 10.0.1.208 |
| EKS Cluster | wiz-exercise |
| ECR Repository | 504784824189.dkr.ecr.us-east-1.amazonaws.com/wiz-exercise-todo-app |
| S3 Bucket (PUBLIC) | wiz-exercise-backups-bfde675c |
| ALB | a60274b82250e4931b580f0e5abb694b-1866901723.us-east-1.elb.amazonaws.com |

---

## Lessons Learned
[Fill in after completing the exercise]

1.
2.
3.

---

## Questions for Wiz Team
[Note any questions that come up during the build]

1.
2.
