# SecureStack — Compliance Framework Mapping

This document maps every security control in the SecureStack platform to the compliance frameworks most commonly required by UK employers: ISO 27001, SOC 2, NIST CSF, OWASP, and Cyber Essentials.

## ISO 27001:2022 — Annex A Controls

| Control | Description | SecureStack Implementation | Evidence |
|---------|-------------|---------------------------|----------|
| A.5.1 | Policies for information security | Information security policy in security/docs/ | security/docs/ |
| A.8.1 | User endpoint devices | Non-root containers, read-only filesystems | k8s/base/deployments.yaml |
| A.8.9 | Configuration management | Terraform IaC, Kyverno policies, Checkov scanning | terraform/, k8s/base/kyverno-policies.yaml |
| A.8.15 | Logging | CloudTrail, VPC Flow Logs, Prometheus, EKS audit logs | terraform/modules/security/, monitoring/ |
| A.8.16 | Monitoring activities | Grafana dashboards, Prometheus alerts, Sigma rules | monitoring/, security/sigma-rules/ |
| A.8.20 | Network security | VPC private subnets, security groups, K8s network policies | terraform/modules/vpc/, k8s/base/network-policies.yaml |
| A.8.21 | Security of network services | WAF, TLS termination, Nginx security headers | terraform/modules/security/, app/frontend/default.conf |
| A.8.24 | Use of cryptography | KMS encryption for EKS secrets, S3, CloudTrail, Secrets Manager | terraform/modules/eks/, terraform/modules/security/ |
| A.8.25 | Secure development lifecycle | 12-stage security pipeline, SAST, DAST, SCA, quality gates | .github/workflows/ci-security.yml |
| A.8.27 | Secure system architecture | Private subnets, namespace isolation, RBAC, least privilege | terraform/modules/vpc/, k8s/base/ |
| A.8.28 | Secure coding | CodeQL SAST, secure coding guide, vulnerability scanning | .github/actions/codeql-sast/ |
| A.8.31 | Separation of environments | Staging and production namespaces with PSS enforcement | k8s/base/namespace.yaml |
| A.8.33 | Test information | Separate test data, no production data in staging | k8s/staging/ vs k8s/production/ |
| A.10.1 | Cryptographic controls | KMS key rotation enabled, encrypted storage | terraform/modules/eks/main.tf |

## SOC 2 — Trust Services Criteria

| Criteria | Description | SecureStack Implementation | Evidence |
|----------|-------------|---------------------------|----------|
| CC1.1 | Control environment | Documented security policies, threat model, risk register | security/docs/ |
| CC2.1 | Information and communication | SNS security alerts, Grafana dashboards, incident notifications | monitoring/, terraform/modules/security/ |
| CC3.1 | Risk assessment | STRIDE threat model, CVSS-scored vulnerability assessment | security/docs/threat-model.md |
| CC4.1 | Monitoring activities | Prometheus alerts, Sigma rules, GuardDuty, Security Hub | monitoring/, security/sigma-rules/ |
| CC5.1 | Control activities | Pipeline quality gates, Kyverno admission control, OPA policies | .github/workflows/, k8s/base/kyverno-policies.yaml |
| CC6.1 | Logical access controls | RBAC, service accounts, JWT auth, IAM least privilege | k8s/base/rbac.yaml, terraform/modules/eks/ |
| CC6.2 | Authorized access | Branch protection, PR reviews, CODEOWNERS | .github/ repository settings |
| CC6.3 | Role-based access | K8s RBAC with named resources, IAM policies | k8s/base/rbac.yaml |
| CC6.6 | External threats | WAF, GuardDuty, network policies, security headers | terraform/modules/security/, app/frontend/default.conf |
| CC6.7 | Restrict data movement | Network policies, restricted egress, S3 public access block | k8s/base/network-policies.yaml, terraform/ |
| CC6.8 | Prevent unauthorized software | Kyverno image registry restriction, SBOM tracking | k8s/base/kyverno-policies.yaml, .github/actions/sbom-generate/ |
| CC7.1 | Detection mechanisms | GuardDuty, Sigma rules, Prometheus alerts | security/sigma-rules/, monitoring/ |
| CC7.2 | Incident response | IR runbook, SOAR auto-response, SNS notifications | security/docs/, scripts/soar-auto-response.py |
| CC7.3 | Remediation | Auto-credential revocation, instance isolation, patching process | scripts/soar-auto-response.py |
| CC8.1 | Change management | Git branching, PR reviews, pipeline gates, Terraform plan/apply | .github/workflows/, terraform/ |

## NIST CSF 2.0

| Function | Category | SecureStack Implementation |
|----------|----------|---------------------------|
| IDENTIFY | Asset Management | Terraform state tracks all infrastructure, SBOM tracks all software components |
| IDENTIFY | Risk Assessment | STRIDE threat model, vulnerability scanning, CVSS scoring |
| IDENTIFY | Governance | Security policies, compliance mapping, documented risk acceptances |
| PROTECT | Access Control | RBAC, IAM least privilege, JWT auth, network policies |
| PROTECT | Data Security | KMS encryption at rest, TLS in transit, S3 bucket policies |
| PROTECT | Platform Security | Hardened containers, PSS restricted, Kyverno admission control |
| PROTECT | Technology Infrastructure | VPC isolation, private subnets, WAF, security groups |
| DETECT | Continuous Monitoring | Prometheus, Grafana, CloudTrail, GuardDuty, Security Hub |
| DETECT | Adverse Event Analysis | Sigma detection rules, alert correlation, brute force detection |
| RESPOND | Incident Management | IR runbook, SOAR auto-response, SNS notifications |
| RESPOND | Incident Analysis | CloudTrail forensics, VPC flow logs, container logs |
| RESPOND | Incident Mitigation | Auto credential revocation, instance isolation, network containment |
| RECOVER | Recovery Planning | Multi-replica deployments, persistent volumes, automated restarts |
| GOVERN | Policy | OPA/Conftest custom policies, Checkov IaC scanning, documented exceptions |

## OWASP Top 10 (2021)

| Risk | SecureStack Coverage |
|------|---------------------|
| A01: Broken Access Control | RBAC, JWT auth, isAdmin middleware, network policies |
| A02: Cryptographic Failures | KMS encryption, bcrypt hashing, HTTPS headers |
| A03: Injection | SQL injection demonstrated and detected by CodeQL + ZAP |
| A04: Insecure Design | STRIDE threat model, security design reviews |
| A05: Security Misconfiguration | Checkov, OPA/Conftest, Kyverno, security headers |
| A06: Vulnerable Components | Trivy SCA, SBOM generation, dependency tracking |
| A07: Auth Failures | JWT with expiry, brute force detection, Sigma rules |
| A08: Software/Data Integrity | Immutable ECR tags, image signing, pipeline integrity |
| A09: Logging Failures | CloudTrail, VPC Flow Logs, Prometheus, EKS audit logs |
| A10: SSRF | Network policies restrict outbound, egress controls |

## Cyber Essentials Plus — 5 Controls

| Control | SecureStack Implementation |
|---------|---------------------------|
| 1. Firewalls | VPC security groups, K8s network policies, WAF |
| 2. Secure Configuration | Checkov IaC scanning, Kyverno policies, hardened Dockerfiles |
| 3. User Access Control | IAM least privilege, RBAC, JWT auth, service accounts |
| 4. Malware Protection | Container image scanning (Trivy), registry restriction (Kyverno) |
| 5. Patch Management | Trivy SCA detects vulnerable dependencies, SBOM for tracking |
