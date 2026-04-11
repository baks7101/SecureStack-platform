# SecureStack Platform

An end-to-end DevSecOps platform demonstrating enterprise-grade security engineering across a 3-tier Node.js application deployed to AWS EKS.

Built to mirror how real security engineering teams embed security across the full software development lifecycle — from code commit to production runtime.

## Architecture

| Layer | Components |
|-------|-----------|
| Application | React frontend, Node.js API, MySQL database |
| CI/CD Pipeline | GitHub Actions with 12 security stages and reusable composite actions |
| Infrastructure | AWS (EKS, ECR, VPC, IAM, WAF, GuardDuty, Security Hub) via Terraform modules |
| Container Orchestration | Kubernetes (EKS) with network policies, RBAC, Pod Security Standards, Kyverno |
| Secrets Management | AWS Secrets Manager + External Secrets Operator (zero hardcoded secrets) |
| Monitoring & Detection | Prometheus, Grafana, Sigma detection rules, CloudTrail |
| Automated Response (SOAR) | EventBridge + Lambda auto-remediation on GuardDuty findings |
| Compliance | ISO 27001, SOC 2, NIST CSF mapping with automated evidence collection |

## Security Pipeline Stages

1. Pre-commit hooks (Gitleaks secret scanning)
2. SAST — CodeQL static analysis
3. SCA — Trivy dependency scanning
4. SBOM generation — Syft (CycloneDX format)
5. Container image scanning — Trivy
6. IaC scanning — Checkov for Terraform
7. Policy-as-code — OPA/Conftest custom policies
8. Security quality gate — pass/fail on severity thresholds
9. DAST — OWASP ZAP against staging environment
10. Artifact signing and push to ECR
11. GitOps deployment via ArgoCD
12. Runtime monitoring and SOAR auto-response

## Key Enterprise Patterns

- **OIDC authentication** — GitHub Actions to AWS with short-lived tokens (zero static keys)
- **Reusable composite actions** — security scans packaged as modular, pluggable actions
- **Terraform modules** — VPC, EKS, and security resources as independent, reusable modules
- **Environment separation** — staging and production namespaces with separate configs
- **Branch protection** — PRs required, security checks must pass, no direct push to main
- **Image integrity** — signed images tagged with Git commit SHA, private ECR registry
- **Policy-as-code** — OPA/Conftest for Terraform, Kyverno admission controller for Kubernetes
- **Detection-as-code** — Sigma rules for attack pattern detection
- **Automated response** — GuardDuty → EventBridge → Lambda (credential revocation, resource isolation)

## Compliance Mapping

Every security control maps to at least one framework requirement:

| Framework | Coverage |
|-----------|----------|
| ISO 27001:2022 | Annex A controls mapped to pipeline and infrastructure controls |
| SOC 2 Type II | Trust Services Criteria mapped to automated evidence collection |
| NIST CSF 2.0 | Identify, Protect, Detect, Respond, Recover functions covered |
| OWASP Top 10 | All 10 categories addressed via SAST, DAST, SCA, and secure coding |
| OWASP LLM Top 10 | Prompt injection, data leakage, and model abuse demonstrated and mitigated |
| Cyber Essentials | 5 technical controls demonstrated |

## Project Structure

