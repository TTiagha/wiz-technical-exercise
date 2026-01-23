# Commands Cheatsheet - Wiz Technical Exercise

Quick reference for all commands used in the exercise.

---

## AWS CLI Commands

### Account & Identity
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `aws sts get-caller-identity` | Show current AWS identity | Account ID, User ARN |
| `aws configure get region` | Show configured region | `us-east-1` |

### EC2
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `aws ec2 describe-instances --filters "Name=tag:Name,Values=wiz-exercise-mongodb"` | Find MongoDB VM | Instance details JSON |
| `aws ec2 describe-security-groups --group-names wiz-exercise-mongo-sg` | Show security group rules | Inbound/outbound rules |
| `aws ec2 describe-vpcs --filters "Name=tag:Project,Values=wiz-technical-exercise"` | List project VPCs | VPC IDs and CIDRs |

### S3
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `aws s3 ls` | List all buckets | Bucket names |
| `aws s3 ls s3://BUCKET_NAME/` | List bucket contents | Files and folders |
| `aws s3 ls s3://BUCKET_NAME/ --no-sign-request` | List PUBLIC bucket (no auth) | Files if public |
| `aws s3 cp s3://BUCKET/file.archive .` | Download file | Local file |

### EKS
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `aws eks list-clusters` | List EKS clusters | Cluster names |
| `aws eks describe-cluster --name wiz-exercise` | Cluster details | Endpoint, version, VPC |
| `aws eks update-kubeconfig --name wiz-exercise --region us-east-1` | Configure kubectl | Config updated message |

### ECR
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `aws ecr describe-repositories` | List repositories | Repo URIs |
| `aws ecr get-login-password \| docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.REGION.amazonaws.com` | Docker login to ECR | Login succeeded |

---

## Terraform Commands

| Command | What It Does | When to Use |
|---------|--------------|-------------|
| `terraform init` | Initialize working directory | First time or after adding providers |
| `terraform fmt` | Format code consistently | Before committing |
| `terraform validate` | Check syntax | After writing code |
| `terraform plan` | Preview changes | Before applying |
| `terraform plan -out=tfplan` | Save plan to file | For CI/CD |
| `terraform apply` | Apply changes | Deploy infrastructure |
| `terraform apply tfplan` | Apply saved plan | CI/CD deployment |
| `terraform output` | Show output values | Get IPs, IDs after apply |
| `terraform output -raw mongodb_public_ip` | Show specific output | Get single value |
| `terraform destroy` | Delete all resources | Teardown |

---

## kubectl Commands

### Basic Operations
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `kubectl get nodes` | List worker nodes | Node names, status |
| `kubectl get pods -n todo-app` | List pods in namespace | Pod names, status |
| `kubectl get pods -A` | List all pods | All namespaces |
| `kubectl get svc -n todo-app` | List services | Service names, IPs |
| `kubectl get ingress -n todo-app` | List ingresses | ALB hostname |

### Inspection
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `kubectl describe pod POD_NAME -n todo-app` | Pod details | Events, containers |
| `kubectl logs POD_NAME -n todo-app` | View pod logs | Application logs |
| `kubectl logs POD_NAME -n todo-app -f` | Follow logs | Live log stream |
| `kubectl exec -it POD_NAME -n todo-app -- /bin/sh` | Shell into pod | Interactive shell |
| `kubectl exec POD_NAME -n todo-app -- cat /app/wizexercise.txt` | Read file in pod | "Tem Muya Tiagha" |

### RBAC Inspection
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `kubectl get serviceaccounts -n todo-app` | List service accounts | SA names |
| `kubectl get clusterrolebindings` | List cluster role bindings | Bindings including todo-app-cluster-admin |
| `kubectl auth can-i --list --as=system:serviceaccount:todo-app:todo-app-sa` | Check SA permissions | All allowed actions |
| `kubectl get secrets -A` | List all secrets | Secret names (if you have access) |

### Deployment Management
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `kubectl apply -f manifest.yaml` | Apply manifest | Resource created/configured |
| `kubectl rollout status deployment/todo-app -n todo-app` | Watch deployment | Completion message |
| `kubectl rollout restart deployment/todo-app -n todo-app` | Restart pods | New pods created |
| `kubectl set image deployment/todo-app todo-app=NEW_IMAGE -n todo-app` | Update image | Deployment updated |
| `kubectl delete namespace todo-app` | Delete namespace and all resources | Namespace deleted |

---

## Docker Commands

### Build & Tag
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `docker build -t wiz-todo-app .` | Build image | Image ID |
| `docker tag wiz-todo-app:latest ACCOUNT.dkr.ecr.REGION.amazonaws.com/REPO:TAG` | Tag for ECR | No output |
| `docker images` | List local images | Image list |

### Push & Pull
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `docker push ACCOUNT.dkr.ecr.REGION.amazonaws.com/REPO:TAG` | Push to ECR | Layer uploads |
| `docker pull ACCOUNT.dkr.ecr.REGION.amazonaws.com/REPO:TAG` | Pull from ECR | Layer downloads |

### Run & Test
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `docker run -p 3000:3000 wiz-todo-app` | Run locally | App starts |
| `docker run --rm wiz-todo-app cat /app/wizexercise.txt` | Check file exists | "Tem Muya Tiagha" |

---

## MongoDB Commands

### Shell Access
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `mongosh` | Open MongoDB shell (local) | Shell prompt |
| `mongosh -u admin -p PASSWORD --authenticationDatabase admin` | Authenticated shell | Shell prompt |

### Database Operations
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `show dbs` | List databases | Database names |
| `use todos` | Switch to database | Switched message |
| `show collections` | List collections | Collection names |
| `db.todos.find()` | List all todos | Todo documents |
| `db.todos.insertOne({text: "Test", completed: false})` | Create todo | Insert confirmation |
| `db.todos.countDocuments()` | Count todos | Number |

### Backup Commands (on MongoDB VM)
```bash
# Manual backup
/opt/mongo-backup.sh

# Check backup log
tail -f /var/log/mongo-backup.log

# View cron job
cat /etc/cron.d/mongo-backup
```

---

## SSH Commands

### Access MongoDB VM
```bash
# Using generated key from Terraform
ssh -i terraform/mongodb-key.pem ubuntu@MONGODB_PUBLIC_IP

# If permission denied
chmod 400 terraform/mongodb-key.pem
```

### Useful Commands on VM
```bash
# Check MongoDB status
sudo systemctl status mongod

# View MongoDB logs
sudo tail -f /var/log/mongodb/mongod.log

# Check IAM role (should show ec2:*, s3:*)
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

---

## AWS Security Controls Commands

### CloudTrail (Audit Logging)
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `aws cloudtrail describe-trails` | List all trails | Trail names, S3 buckets |
| `aws cloudtrail get-trail-status --name wiz-exercise-trail` | Check if logging | `IsLogging: true` |
| `aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=CreateSecurityGroup --max-items 5` | Search for specific API calls | Event history JSON |
| `aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances --max-items 5` | Find EC2 launches | Who created instances |

### AWS Config (Configuration Compliance)
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `aws configservice describe-configuration-recorders` | Check Config is recording | Recorder name, role |
| `aws configservice describe-config-rules` | List all Config rules | Rule names, states |
| `aws configservice get-compliance-details-by-config-rule --config-rule-name s3-bucket-public-read-prohibited` | Check S3 public bucket findings | NON_COMPLIANT resources |
| `aws configservice get-compliance-details-by-config-rule --config-rule-name restricted-ssh` | Check SSH exposure findings | NON_COMPLIANT security groups |
| `aws configservice get-compliance-details-by-config-rule --config-rule-name s3-bucket-public-read-prohibited --compliance-types NON_COMPLIANT` | Only show violations | List of public buckets |
| `aws configservice get-compliance-summary-by-config-rule` | Overall compliance summary | Compliant/NonCompliant counts |

### GuardDuty (Threat Detection)
| Command | What It Does | Expected Output |
|---------|--------------|-----------------|
| `aws guardduty list-detectors` | List detector IDs | Detector ID (UUID) |
| `aws guardduty get-detector --detector-id DETECTOR_ID` | Check detector status | `Status: ENABLED` |
| `aws guardduty list-findings --detector-id DETECTOR_ID` | List security findings | Finding IDs (if threats detected) |
| `aws guardduty get-findings --detector-id DETECTOR_ID --finding-ids FINDING_ID` | Get finding details | Threat type, severity |

### Quick Security Controls Check
```bash
# 1. Verify CloudTrail is logging
aws cloudtrail get-trail-status --name wiz-exercise-trail --query 'IsLogging'

# 2. Check Config compliance for public S3 (should show our bucket!)
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name s3-bucket-public-read-prohibited \
  --compliance-types NON_COMPLIANT \
  --query 'EvaluationResults[*].EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId'

# 3. Check Config compliance for SSH (should show our security group!)
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name restricted-ssh \
  --compliance-types NON_COMPLIANT \
  --query 'EvaluationResults[*].EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId'

# 4. Verify GuardDuty is enabled
aws guardduty list-detectors --query 'DetectorIds[0]' --output text
```

---

## Verification Commands

### Quick Health Check
```bash
# 1. Check AWS access
aws sts get-caller-identity

# 2. Check EKS
kubectl get nodes

# 3. Check app pods
kubectl get pods -n todo-app

# 4. Check app logs
kubectl logs -l app=todo-app -n todo-app --tail=50

# 5. Get app URL
kubectl get ingress -n todo-app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# 6. Test app endpoint
curl -s http://ALB_HOSTNAME/health

# 7. Verify wizexercise.txt
kubectl exec $(kubectl get pods -n todo-app -l app=todo-app -o jsonpath='{.items[0].metadata.name}') -n todo-app -- cat /app/wizexercise.txt
```

### Security Finding Verification
```bash
# 1. SSH exposed (should connect from anywhere)
ssh -i mongodb-key.pem ubuntu@MONGODB_IP

# 2. S3 public (should list without auth)
aws s3 ls s3://wiz-exercise-backups-XXXX/ --no-sign-request

# 3. Check IAM role from VM
ssh ubuntu@MONGODB_IP "curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/"

# 4. Check cluster-admin binding
kubectl get clusterrolebinding todo-app-cluster-admin -o yaml
```



 Absolute Must-Know (Memorize These)                                         
  # 1. Who am I?                                                           
  aws sts get-caller-identity

  # 2. Show security group rules (YOUR KEY FINDING)
  aws ec2 describe-security-groups --group-ids sg-XXXX

  # 3. Prove S3 is public (no auth needed)
  aws s3 ls s3://bucket-name/ --no-sign-request

  # 4. Check IAM role attached to instance
  aws ec2 describe-instances --instance-ids i-XXXX --query
  "Reservations[*].Instances[*].IamInstanceProfile"

  # 5. List pods
  kubectl get pods -n NAMESPACE

  # 6. Check what a service account can do (proves cluster-admin)
  kubectl auth can-i --list --as=system:serviceaccount:todo-app:todo-app-sa

  # 7. Show the dangerous role binding
  kubectl get clusterrolebinding todo-app-cluster-admin -o yaml

  # 8. Read a file in a pod (verify wizexercise.txt)
  kubectl exec POD_NAME -n todo-app -- cat /app/wizexercise.txt

  # 9. Check AWS Config compliance (proves native detection works)
  aws configservice get-compliance-details-by-config-rule \
    --config-rule-name s3-bucket-public-read-prohibited \
    --compliance-types NON_COMPLIANT

  # 10. Verify GuardDuty is enabled
  aws guardduty list-detectors

  Nice-to-Know (Reference Sheet OK)

  Everything else - keep COMMANDS_CHEATSHEET.md open during the interview  
  if allowed, or printed out.

  ---
  The story matters more than syntax. If you say "I'd check the security   
  group ingress rules to verify SSH is exposed to 0.0.0.0/0" - that shows  
  understanding even if you don't remember the exact --query flag.