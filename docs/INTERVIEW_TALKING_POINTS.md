# Interview Talking Points - Wiz Technical Exercise

**Candidate:** Tem Muya Tiagha
**Duration:** 45 minutes (including demo)
**Slides:** 12 total

---

## The Core Skill Being Tested

> "Our goal is to validate if a candidate can successfully explain why something is a security risk **in isolation** but also explain why it may be **elevated in severity** if it can be clearly **chained with other security risks**."

Every finding should have two parts:
1. **Isolated Risk** - What's the danger if this is the only issue?
2. **Chained Risk** - How does this combine with other findings to create a critical path?

---

## Slide 1: Title

**What to Say:**
> "I'm Tem Muya Tiagha. Today I'll walk through a cloud environment I built with intentional security misconfigurations, show how they chain together into attack paths, and demonstrate why context-aware security tools like Wiz matter."

**Key:** Set the expectation that this is about attack paths, not just a list of findings.

---

## Slide 2: Architecture Overview

**What to Say:**
> "This is a typical two-tier architecture: users access a todo application through a load balancer, the app runs on Kubernetes in private subnets, and data is stored in MongoDB. I built this with Terraform to mirror real-world 'quick deployment' patterns."

**Key Points to Mention:**
- VPC with public/private subnet separation
- MongoDB intentionally in public subnet (one of our findings)
- EKS correctly in private subnets (contrast with MongoDB)
- S3 bucket for backups (public - intentional)

**If Asked "Why Terraform?":**
> "I started manually with CLI, then switched to Terraform. This mirrors what customers do - start fast, then mature to IaC. With IaC, Wiz can scan configurations *before* deployment. With manual CLI, you only catch issues *after* they're live."

---

## Slide 3: Vulnerabilities Summary

**What to Say:**
> "I've built six intentional weaknesses. Let me show them all at once, then we'll deep-dive into the most critical ones."

**Walk Through the Table:**

| Finding | What's Wrong | Isolated | Chained |
|---------|--------------|----------|---------|
| SSH Exposed | 0.0.0.0/0 on port 22 | MEDIUM | CRITICAL |
| Public S3 | Backups readable by anyone | CRITICAL | CATASTROPHIC |
| Overpermissive IAM | ec2:*, s3:* permissions | HIGH | CRITICAL |
| cluster-admin | App has full K8s access | HIGH | CRITICAL |
| Outdated OS | Ubuntu 20.04 | MEDIUM | HIGH |
| Outdated DB | MongoDB 4.4 (EOL) | MEDIUM | HIGH |

**Key Line:**
> "Notice how the same finding has different severity based on context. That's the core insight - and it's what Wiz does that native tools don't."

---

## Slide 4: Deep-Dive - SSH Exposure + Chain

**What to Say (Isolated - MEDIUM):**
> "SSH on port 22 exposed to 0.0.0.0/0 means anyone on the internet can attempt to connect. This enables brute-force attacks. By itself, with strong SSH keys and an up-to-date OS, this might be manageable."

**What to Say (Chained - CRITICAL):**
> "But here's where it gets interesting. This VM runs Ubuntu 20.04 with known kernel CVEs. An attacker who gains SSH access could exploit these to get root. And because the VM has an IAM role with ec2:* and s3:*, that root access translates to full AWS account access."

**Draw or Show the Chain:**
```
Internet → SSH → Ubuntu Exploit → Root → IAM Role → AWS Account Takeover
```

**Key Line:**
> "Three findings that look medium/high individually become a CRITICAL path when connected."

---

## Slide 5: Deep-Dive - Public S3 Bucket

**What to Say (Isolated - CRITICAL):**
> "This is CRITICAL even in isolation. The backup bucket is publicly readable. Anyone on the internet can list and download our MongoDB backups. No exploitation required - just a web browser or curl command."

**What to Say (Chained - CATASTROPHIC):**
> "The backups contain MongoDB credentials and all application data. An attacker who downloads the backup can extract credentials and directly access the live database. This is why context matters - a public bucket with marketing images is LOW risk. A public bucket with database backups is CRITICAL."

**Demo Command (if asked):**
```bash
aws s3 ls s3://wiz-exercise-backups-bfde675c/ --no-sign-request
```

**Key Line:**
> "This is the easiest attack path - zero technical skill required. Anyone with a browser can steal our data right now."

---

## Slide 6: Deep-Dive - cluster-admin RBAC

**What to Say (Isolated - HIGH):**
> "The todo application's Kubernetes service account has cluster-admin privileges. This means the app can read every secret in the cluster, modify any deployment, delete any resource."

**What to Say (Chained - CRITICAL):**
> "If our application has ANY vulnerability - SSRF, RCE, Log4Shell, anything - the attacker immediately has full Kubernetes cluster access. They can read MongoDB credentials from secrets, deploy cryptominers, or ransom the cluster."

**Key Line:**
> "The blast radius of cluster-admin is the entire cluster. One app vulnerability becomes total cluster compromise."

---

## Slide 7: Complete Attack Paths

**What to Say:**
> "Let me tie this all together. I've identified three distinct entry points, each leading to full data compromise."

**Walk Through Each Path:**

**Path 1 - MongoDB VM:**
```
Internet → SSH (0.0.0.0/0) → Ubuntu Exploit → Root → IAM Role → AWS Account
```
> "Requires finding an exploit, but leads to full AWS account takeover."

**Path 2 - Kubernetes App:**
```
Internet → ALB → App Vulnerability → Pod → cluster-admin → All Secrets → Database
```
> "Requires an app vulnerability, but leads to full cluster access."

**Path 3 - Public S3 (EASIEST):**
```
Internet → S3 → Download Backup → Extract Credentials → Direct Database Access
```
> "Requires ZERO exploitation. Just download and extract."

**Key Line:**
> "Three paths, one outcome: full data access. The S3 path requires zero technical skill. That's our first fix."

---

## Slide 8: Three-Layer Security Controls

**What to Say:**
> "Let me show you the three layers of security controls I implemented, and importantly - the order they run in a mature DevSecOps pipeline."

**The Three Layers:**

| Layer | Tools | When It Runs | What It Catches |
|-------|-------|--------------|-----------------|
| **Preventive** | tfsec + Trivy in CI/CD | Before deployment | IaC misconfigs + container vulns |
| **Audit** | CloudTrail | During runtime | All API activity |
| **Detective** | AWS Config + GuardDuty | After deployment | Compliance violations + threats |

**The Story (Important Context):**
> "I deployed the infrastructure via Terraform, then pushed the code to GitHub. The GitHub Actions pipeline runs tfsec on Terraform files and Trivy on container images. If I had this pipeline from day one, these vulnerabilities would have been flagged BEFORE reaching AWS."

**tfsec Results (IaC Scanner) - 53 Findings:**

| Severity | Count | Examples |
|----------|-------|----------|
| CRITICAL | 9 | SSH 0.0.0.0/0, Public S3, EKS public access |
| HIGH | 31 | Wildcard IAM (ec2:*, s3:*), missing encryption |
| MEDIUM | 8 | Missing logging configurations |
| LOW | 5 | Missing public access blocks |

**Sample tfsec Output:**
```
Result #6 CRITICAL - Security group allows ingress from public internet
  security_groups.tf:22  cidr_blocks = ["0.0.0.0/0"]

Result #17 HIGH - IAM policy document uses wildcards
  iam.tf:45  Action = ["ec2:*", "s3:*"]
```

**Trivy Results (Container Scanner) - 39 Findings:**

| Severity | Count | Examples |
|----------|-------|----------|
| CRITICAL | 0 | - |
| HIGH | 10 | OpenSSL CVE-2023-5363, node-tar CVE-2026-23745 |
| MEDIUM | 29 | busybox use-after-free, semver ReDoS |

**Sample Trivy Output:**
```
node:16-alpine (alpine 3.18.3)
Total: 34 (HIGH: 6, MEDIUM: 28)

│ libcrypto3 │ CVE-2023-5363 │ HIGH │ openssl: Incorrect cipher key processing │
│ musl       │ CVE-2025-26519│ HIGH │ musl libc vulnerability                  │
```

**Key Line:**
> "Between tfsec and Trivy, the pipeline found 92 issues - including all 6 of our intentional IaC vulnerabilities AND outdated base image packages. This is the 'shift-left' value: catch issues before they reach production."

---

## Slide 9: AWS Native Detective Controls

**What to Say:**
> "Once deployed, AWS native tools provide detective capabilities. I enabled CloudTrail, AWS Config, and GuardDuty."

**Walk Through Each Tool:**

| Tool | Type | What It Does | Limitation |
|------|------|--------------|------------|
| CloudTrail | Audit | Logs all API calls | Reactive - after the fact |
| AWS Config | Detective | Evaluates compliance | Only tells WHAT, not WHY |
| GuardDuty | Detective | Detects threats | After suspicious activity |

**Demo (if time):**
```bash
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name s3-bucket-public-read-prohibited \
  --compliance-types NON_COMPLIANT
```

> "See? It found our bucket is NON_COMPLIANT. But it doesn't tell us what's IN the bucket or why it matters."

**Key Line:**
> "Each tool provides a piece of the puzzle. But none of them show the attack path."

---

## Slide 9: The Gap - What Native Tools Miss

**What to Say:**
> "Here's the gap. Let me show you side by side."

**Contrast:**

| AWS Config Says | What We Need to Know |
|-----------------|----------------------|
| "S3 bucket is public" | "S3 bucket contains database backups with MongoDB credentials that would give access to production data including customer PII" |
| Result: NON_COMPLIANT | Severity: CRITICAL |
| Severity: HIGH | Business Impact: Data breach |

**Key Line:**
> "Config tells me WHAT is wrong. I need to know WHY it matters. That context gap is where Wiz adds value."

---

## Slide 10: Wiz Value Proposition

**What to Say:**
> "This is exactly what Wiz does better than native tools."

**Walk Through Comparison:**

| Capability | Native Tools | Wiz |
|------------|--------------|-----|
| Find public S3 | Yes | Yes + what sensitive data is inside |
| Find SSH exposed | Yes | Yes + what it chains to |
| Show attack paths | No | Yes |
| Context-aware severity | No | Yes |
| Agentless scanning | N/A | Yes |

**Key Wiz Capabilities:**
1. **Attack Path Analysis** - Connects findings into exploitable chains
2. **Context-Aware Severity** - Same finding, different severity based on data exposure
3. **Agentless Scanning** - Found outdated MongoDB/Ubuntu without installing anything
4. **Cross-Domain Correlation** - VM + K8s + S3 findings in unified view

**The Killer Line:**
> "Traditional tools show 6 findings. Wiz shows 3 attack paths to breach. That's the difference between 'here's what's wrong' and 'here's what matters.'"

---

## Slide 11: Remediation Recommendations

**What to Say:**
> "If I were advising this customer, I'd prioritize based on attack paths, not individual severities."

**Priority Order:**

| Priority | Fix | Why First |
|----------|-----|-----------|
| 1 (Immediate) | Make S3 bucket private | No exploit needed to abuse |
| 1 (Immediate) | Restrict SSH to VPN CIDR | Closes entry point |
| 2 (This Week) | Reduce IAM to s3:PutObject only | Limits blast radius |
| 2 (This Week) | Remove cluster-admin | Defense in depth |
| 3 (This Month) | Upgrade Ubuntu/MongoDB | Reduces exploitation surface |

**Before/After Summary:**

| Finding | Vulnerable | Remediated |
|---------|------------|------------|
| SSH | `0.0.0.0/0` | `10.0.0.0/8` (VPN only) |
| S3 | `Principal: "*"` | `Principal: specific-role-arn` |
| IAM | `ec2:*, s3:*` | `s3:PutObject` on one bucket |
| K8s | `cluster-admin` | `Role: get specific secret` |

**Key Line:**
> "Remediation follows attack path priority, not individual finding severity."

---

## Slide 12: Summary & Demo Offer

**Key Takeaways:**
> "Let me leave you with four key points:"

1. **Same finding = different severity based on context**
2. **Attack paths > individual findings for prioritization**
3. **Native tools detect; Wiz contextualizes**
4. **Remediation should follow attack path priority**

**Demo Offer:**
> "I'm happy to demonstrate any of these live:"
- Public S3 access (no auth required)
- AWS Config NON_COMPLIANT findings
- cluster-admin permissions in K8s
- The complete attack path walkthrough

**Closing Statement:**
> "Security is about understanding risk, not counting findings. As a TAM, I'd help customers understand not just their findings, but their actual risk - the attack paths that could lead to breach. That's the conversation that drives action, and that's what excites me about Wiz."

---

## Anticipated Questions & Answers

### Architecture & Design

**Q: "Why did you choose these specific weaknesses?"**
> "I chose weaknesses that represent real-world misconfigurations - SSH exposed during development and never locked down, IAM roles copied from Stack Overflow without reduction, S3 buckets made public for a quick test. These are 'temporary' changes that become permanent."

**Q: "What if the MongoDB was in a private subnet?"**
> "Great question. The SSH finding would be eliminated - no public exposure. However, the public S3 bucket would still be CRITICAL because backups are still accessible. And cluster-admin would still allow lateral movement. Defense in depth matters."

**Q: "Why did you use Terraform instead of manual CLI?"**
> "I started manually, then switched. This mirrors customer maturity. With IaC, Wiz can scan before deployment (shift-left). With manual CLI, you only catch issues after they're live. Also, Wiz detects drift between IaC and running state."

### Wiz vs Native Tools

**Q: "What's the difference between AWS Config and Wiz?"**
> "Config tells me a bucket is public - that's a binary check. Wiz tells me that public bucket contains database backups with MongoDB credentials that would give access to production data with customer PII. Same finding, completely different business impact."

**Q: "Why use Wiz if you already have GuardDuty?"**
> "GuardDuty detects active threats - someone's already doing bad things. Wiz shows paths they COULD take before exploitation. GuardDuty is your alarm system; Wiz is your penetration tester showing weak spots."

**Q: "What's the difference between Wiz and a traditional vulnerability scanner?"**
> "A scanner gives me a list: 'SSH exposed - MEDIUM, Old MongoDB - MEDIUM, Public S3 - HIGH.' Wiz shows me: 'Here's a path from internet to your database in 3 steps.' It answers 'so what?' instead of just 'what's wrong?'"

### Technical Deep-Dive

**Q: "Explain CIDR notation 0.0.0.0/0"**
> "CIDR notation defines IP ranges. The /0 means zero bits are fixed, so all 32 bits can vary - every IP from 0.0.0.0 to 255.255.255.255. It means 'allow from anywhere on the internet.'"

**Q: "What's the difference between a Security Group and NACL?"**
> "Security groups are stateful firewalls on resources - allow inbound, response is automatic. NACLs are stateless subnet-level firewalls - must allow both directions. Security groups are typically sufficient."

**Q: "How does IRSA work?"**
> "EKS creates an OIDC provider that AWS IAM trusts. When you annotate a K8s service account with an IAM role ARN, the pod assumes that role using OIDC tokens. Eliminates hardcoded credentials."

**Q: "What's the blast radius of cluster-admin?"**
> "With cluster-admin: read all secrets, modify all deployments, create privileged pods, delete resources. Blast radius is entire cluster plus potentially underlying infrastructure via node access."

**Q: "What AWS Config rules did you enable?"**
> "Two managed rules: S3_BUCKET_PUBLIC_READ_PROHIBITED and INCOMING_SSH_DISABLED. Both flag our intentional misconfigurations as NON_COMPLIANT."

**Q: "How does CloudTrail help with incident response?"**
> "CloudTrail answers: What did the attacker do? When? From where? If stolen IAM credentials spun up crypto miners, CloudTrail shows the CreateInstances call, source IP, and timestamp. It's your forensic audit trail."

**Q: "What's the difference between preventative and detective controls?"**
> "Preventative stops bad things - like an SCP blocking public S3 creation. Detective alerts after - like Config flagging an existing public bucket. A mature posture needs both."

### Handling Unknowns

**Q: [Something you don't know]**
> "That's a great question. I'd want to research that further before giving you a definitive answer. My instinct is [give best guess if reasonable], but I'd verify that."

---

## Demo Commands Quick Reference

```bash
# 1. Prove S3 is public (no auth!)
aws s3 ls s3://wiz-exercise-backups-bfde675c/ --no-sign-request

# 2. Show AWS Config detected it
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name s3-bucket-public-read-prohibited \
  --compliance-types NON_COMPLIANT

# 3. Show SSH is exposed
aws ec2 describe-security-groups --group-names wiz-exercise-mongo-sg \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`].IpRanges"

# 4. Show cluster-admin binding
kubectl get clusterrolebinding todo-app-cluster-admin -o yaml

# 5. Prove wizexercise.txt exists
kubectl exec $(kubectl get pods -n todo-app -l app=todo-app -o jsonpath='{.items[0].metadata.name}') \
  -n todo-app -- cat /app/wizexercise.txt

# 6. Run tfsec locally (IaC scanning)
tfsec terraform/ --no-color

# 7. Run Trivy locally (container scanning)
docker build -t wiz-todo-app:scan app/
trivy image --severity CRITICAL,HIGH,MEDIUM wiz-todo-app:scan

# 8. Show GitHub Actions pipeline runs
# Visit: https://github.com/TTiagha/wiz-technical-exercise/actions
```

---

## Presentation Tips

1. **Speak slowly** - Nerves make you rush
2. **Draw attack paths** - Visuals are more memorable than words
3. **Pause after key points** - Let important lines land
4. **Tie to business impact** - "This leads to data breach" > "This is HIGH severity"
5. **Admit unknowns** - "I'd want to research that" is better than guessing wrong
