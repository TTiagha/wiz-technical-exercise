# Wiz Technical Exercise

**Candidate:** Tem Muya Tiagha

A demonstration environment showing cloud security misconfigurations and attack path analysis for the Wiz Associate TAM technical interview.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                       │
├─────────────────────────────┬───────────────────────────────────┤
│      Public Subnets         │        Private Subnets            │
│   (10.0.1.0/24, 10.0.2.0/24)│   (10.0.101.0/24, 10.0.102.0/24) │
├─────────────────────────────┼───────────────────────────────────┤
│                             │                                   │
│  ┌─────────────────────┐    │    ┌─────────────────────────┐   │
│  │   MongoDB VM        │    │    │    EKS Cluster          │   │
│  │   Ubuntu 20.04      │    │    │    ┌───────────────┐    │   │
│  │   MongoDB 4.4       │◄───┼────┤    │  Todo App     │    │   │
│  │   SSH: 0.0.0.0/0 ⚠  │    │    │    │  (2 replicas) │    │   │
│  └─────────────────────┘    │    │    └───────────────┘    │   │
│           │                 │    │           │              │   │
│           │                 │    │           │              │   │
│           ▼                 │    │           ▼              │   │
│  ┌─────────────────────┐    │    │    ┌───────────────┐    │   │
│  │   S3 Bucket ⚠       │    │    │    │      ALB      │    │   │
│  │   (PUBLIC!)         │    │    │    │   (internet)  │    │   │
│  │   MongoDB backups   │    │    │    └───────────────┘    │   │
│  └─────────────────────┘    │    │                          │   │
│                             │    └──────────────────────────┘   │
└─────────────────────────────┴───────────────────────────────────┘
```

## Intentional Security Weaknesses

| Finding | Isolated Risk | Chained Risk |
|---------|--------------|--------------|
| SSH exposed (0.0.0.0/0) | MEDIUM | CRITICAL |
| Ubuntu 20.04 (outdated) | MEDIUM | HIGH |
| MongoDB 4.4 (EOL) | MEDIUM | HIGH |
| IAM role (ec2:*, s3:*) | HIGH | CRITICAL |
| S3 bucket (public) | CRITICAL | CATASTROPHIC |
| cluster-admin on app | HIGH | CRITICAL |

## Quick Start

### Prerequisites
- AWS CLI configured
- Terraform 1.7+
- Docker
- kubectl

### Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Configure kubectl
```bash
aws eks update-kubeconfig --name wiz-exercise --region us-east-1
```

### Build & Deploy App
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.us-east-1.amazonaws.com

# Build and push
cd app
docker build -t wiz-todo-app .
docker tag wiz-todo-app:latest ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/wiz-exercise-todo-app:latest
docker push ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/wiz-exercise-todo-app:latest

# Deploy to K8s
kubectl apply -f k8s/
```

### Verify
```bash
# Check pods
kubectl get pods -n todo-app

# Verify wizexercise.txt
kubectl exec $(kubectl get pods -n todo-app -l app=todo-app -o jsonpath='{.items[0].metadata.name}') -n todo-app -- cat /app/wizexercise.txt
```

## Documentation

- [Build Tracker](docs/WIZ_BUILD_TRACKER.md) - Step-by-step build log
- [Commands Cheatsheet](docs/COMMANDS_CHEATSHEET.md) - All commands reference
- [Interview Talking Points](docs/INTERVIEW_TALKING_POINTS.md) - Presentation prep

## Teardown

```bash
kubectl delete namespace todo-app
cd terraform && terraform destroy -auto-approve
```

---

**IMPORTANT:** This environment contains intentional security vulnerabilities for educational purposes. Do not deploy in production.
