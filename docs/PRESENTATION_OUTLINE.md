# Wiz Technical Exercise - Presentation Outline

**Candidate:** Tem Muya Tiagha
**Duration:** 45 minutes (including demo)
**Slides:** 12 total

---

## Slide 1: Title Slide

**Title:** Wiz Associate TAM Technical Exercise
**Subtitle:** Cloud Security Assessment & Attack Path Analysis
**Name:** Tem Muya Tiagha
**Date:** [Your Interview Date]

---

## Slide 2: What I Built - Architecture Overview

**Visual:** Network diagram showing:
```
┌─────────────────────────────────────────────────────────────┐
│                         AWS VPC                             │
│  ┌─────────────────────┐    ┌─────────────────────────────┐│
│  │   PUBLIC SUBNET     │    │      PRIVATE SUBNET         ││
│  │                     │    │                             ││
│  │  ┌─────────────┐    │    │    ┌─────────────────┐     ││
│  │  │ MongoDB VM  │    │    │    │   EKS Cluster   │     ││
│  │  │ (Ubuntu 20) │    │    │    │   (todo-app)    │     ││
│  │  │ SSH:22 ────────────────────►│                 │     ││
│  │  │ 0.0.0.0/0   │    │    │    └────────┬────────┘     ││
│  │  └─────────────┘    │    │             │              ││
│  │         │           │    │             │              ││
│  └─────────┼───────────┘    └─────────────┼──────────────┘│
│            │                              │               │
│            ▼                              ▼               │
│     ┌──────────────┐              ┌──────────────┐       │
│     │ S3 Backups   │              │     ALB      │       │
│     │ (PUBLIC!)    │              │              │       │
│     └──────────────┘              └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │
                      Internet Users
```

**Bullet Points:**
- Two-tier web application: Todo App + MongoDB
- Infrastructure as Code (Terraform)
- Intentional security misconfigurations for analysis
- Mirrors real-world "quick deployment" patterns

---

## Slide 3: Intentional Vulnerabilities Summary

**Visual:** Table format

| Finding | What's Wrong | Isolated Risk | Chained Risk |
|---------|--------------|---------------|--------------|
| SSH Exposed | 0.0.0.0/0 on port 22 | MEDIUM | CRITICAL |
| Public S3 | Backups readable by anyone | CRITICAL | CATASTROPHIC |
| Overpermissive IAM | ec2:*, s3:* permissions | HIGH | CRITICAL |
| cluster-admin | App has full K8s access | HIGH | CRITICAL |
| Outdated OS | Ubuntu 20.04 (2+ years) | MEDIUM | HIGH |
| Outdated DB | MongoDB 4.4 (EOL) | MEDIUM | HIGH |

**Key Point:** "Same finding, different severity based on context"

---

## Slide 4: Finding Deep-Dive - SSH Exposure

**Visual:** Attack path diagram

```
ISOLATED (MEDIUM):                 CHAINED (CRITICAL):
┌──────────┐                       ┌──────────┐
│ Internet │                       │ Internet │
└────┬─────┘                       └────┬─────┘
     │                                  │
     ▼                                  ▼
┌──────────┐                       ┌──────────┐
│   SSH    │                       │   SSH    │
│  Access  │                       │  Access  │
└────┬─────┘                       └────┬─────┘
     │                                  │
     ▼                                  ▼
┌──────────┐                       ┌──────────┐
│  ???     │                       │ Ubuntu   │──► Kernel Exploit
└──────────┘                       │ 20.04    │
                                   └────┬─────┘
                                        │
                                        ▼
                                   ┌──────────┐
                                   │ IAM Role │──► ec2:*, s3:*
                                   └────┬─────┘
                                        │
                                        ▼
                                   ┌──────────┐
                                   │  AWS     │
                                   │ Account  │
                                   │ Takeover │
                                   └──────────┘
```

**Script:** "By itself, SSH exposed might just enable brute-force attempts. But chained with outdated Ubuntu and overpermissive IAM, it becomes a path to full account compromise."

---

## Slide 5: Finding Deep-Dive - Public S3 Bucket

**Visual:** Simple diagram showing public access

```
┌──────────────┐          ┌────────────────────┐
│   Anyone     │ ──────►  │  S3 Bucket         │
│   Online     │   No     │  ────────────────  │
│              │   Auth!  │  backup-20240115   │
└──────────────┘          │  backup-20240114   │
                          │  backup-20240113   │
                          └────────────────────┘
                                   │
                                   ▼
                          ┌────────────────────┐
                          │  MongoDB Creds     │
                          │  App Secrets       │
                          │  Customer Data     │
                          └────────────────────┘
```

**Key Point:** "CRITICAL even in isolation - no exploitation required!"

**Command to Demo:**
```bash
aws s3 ls s3://wiz-exercise-backups-bfde675c/ --no-sign-request
```

---

## Slide 6: Finding Deep-Dive - cluster-admin RBAC

**Visual:** Kubernetes access diagram

```
Normal App Should Have:          Our App Has:
┌─────────────────────┐         ┌─────────────────────┐
│ Pod: todo-app       │         │ Pod: todo-app       │
│ ─────────────────── │         │ ─────────────────── │
│ Can: Read 1 secret  │         │ Can: EVERYTHING     │
│      (mongo-creds)  │         │ ─────────────────── │
│                     │         │ - Read ALL secrets  │
│                     │         │ - Modify deployments│
│                     │         │ - Delete resources  │
│                     │         │ - Create pods       │
└─────────────────────┘         └─────────────────────┘
```

**Script:** "If our app has ANY vulnerability - SSRF, RCE, anything - the attacker immediately gets full cluster access."

---

## Slide 7: Complete Attack Paths

**Visual:** Three entry points diagram

```
ENTRY POINT 1: MongoDB VM
Internet ──► SSH ──► Ubuntu Exploit ──► Root ──► IAM ──► AWS Account

ENTRY POINT 2: Kubernetes App
Internet ──► ALB ──► App Vuln ──► Pod ──► cluster-admin ──► All Secrets

ENTRY POINT 3: Public S3 (EASIEST!)
Internet ──► S3 ──► Download ──► Extract Creds ──► Database Access
   │
   └── NO EXPLOITATION REQUIRED
```

**Script:** "Three paths, one outcome: full data access. The S3 path requires zero technical skill."

---

## Slide 8: AWS Native Security Controls

**Visual:** Three-column comparison

| CloudTrail | AWS Config | GuardDuty |
|------------|------------|-----------|
| Logs API calls | Evaluates compliance | Detects threats |
| **Reactive** | **Detective** | **Detective** |
| "What happened?" | "What's misconfigured?" | "What's suspicious?" |
| After the fact | After deployment | After activity |

**Demo:** Show Config detecting our public S3
```bash
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name s3-bucket-public-read-prohibited \
  --compliance-types NON_COMPLIANT
```

**Script:** "These tools each provide a piece. But none show the attack path."

---

## Slide 9: The Gap - What Native Tools Miss

**Visual:** Side-by-side comparison

```
AWS Config Says:                    What We Need to Know:
────────────────                    ────────────────────
"S3 bucket is public"               "S3 bucket contains database
                                     backups with MongoDB credentials
Result: NON_COMPLIANT                that would give access to
                                     production data including
Severity: HIGH                       customer PII"

                                    Severity: CRITICAL
                                    Business Impact: Data breach
```

**Script:** "Config tells me WHAT is wrong. I need to know WHY it matters."

---

## Slide 10: Wiz Value Proposition

**Visual:** Feature comparison table

| Capability | Native Tools | Wiz |
|------------|--------------|-----|
| Find public S3 | Yes | Yes + what data is inside |
| Find SSH exposed | Yes | Yes + what it chains to |
| Show attack paths | No | Yes |
| Context-aware severity | No | Yes |
| Agentless scanning | N/A | Yes |

**Key Message:** "From 'what's wrong' to 'what matters'"

**Quote:** "Traditional tools show 6 findings. Wiz shows 3 attack paths to breach."

---

## Slide 11: Remediation - Before & After

**Visual:** Code comparison

| Finding | BEFORE (Vulnerable) | AFTER (Secure) |
|---------|---------------------|----------------|
| SSH | `0.0.0.0/0` | `10.0.0.0/8` (VPN only) |
| S3 | `Principal: "*"` | `Principal: specific-role` |
| IAM | `ec2:*, s3:*` | `s3:PutObject on one bucket` |
| K8s | `cluster-admin` | `Role: get specific secret` |

**Script:** "Remediation prioritized by attack path severity, not individual finding severity."

**Priority Order:**
1. Make S3 private (no exploit needed)
2. Restrict SSH (reduces attack surface)
3. Reduce IAM (limits blast radius)
4. Fix K8s RBAC (defense in depth)

---

## Slide 12: Summary & Demo Offer

**Key Takeaways:**
1. Same finding = different severity based on context
2. Attack paths > individual findings for prioritization
3. Native tools detect; Wiz contextualizes
4. Remediation should follow attack path priority

**Live Demo Available:**
- Show public S3 access
- Show Config NON_COMPLIANT findings
- Show cluster-admin permissions
- Walk through attack path

**Closing:** "Security is about understanding risk, not counting findings. That's what excites me about Wiz."

---

## Appendix: Demo Commands Quick Reference

```bash
# 1. Prove S3 is public
aws s3 ls s3://wiz-exercise-backups-bfde675c/ --no-sign-request

# 2. Show Config detected it
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
```

---

## Notes for Creating Slides

1. **Use Wiz brand colors** if available (or clean professional colors)
2. **Keep text minimal** - these are talking points, not scripts
3. **Diagrams are key** - visual attack paths are more memorable
4. **Practice the demo** - know the commands by heart
5. **Have backup screenshots** in case live demo fails
