# SecureStack Platform

An end-to-end DevSecOps platform demonstrating enterprise-grade security engineering across a 3-tier Node.js application deployed to AWS EKS.

Built to mirror how real security engineering teams embed security across the full software development lifecycle — from code commit to production runtime.

## Architecture

| Layer | Components |
|-------|-----------|
| Application | React frontend, Node.js API, MySQL database |
| CI/CD Pipeline | GitHub Actions with 8 parallel security stages and reusable composite actions |
| Infrastructure | AWS (EKS, ECR, VPC, IAM, WAF, GuardDuty, Security Hub) via Terraform modules |
| Container Orchestration | Kubernetes (EKS) with network policies, RBAC, Pod Security Standards, Kyverno |
| Secrets Management | AWS Secrets Manager + External Secrets Operator (zero hardcoded secrets) |
| Monitoring & Detection | Prometheus, Grafana, Sigma detection rules, CloudTrail |
| Automated Response (SOAR) | EventBridge + Lambda auto-remediation on GuardDuty findings |
| AI Security | Vulnerable + secure LLM endpoints with OWASP LLM Top 10 mapping |
| Compliance | ISO 27001, SOC 2, NIST CSF, Cyber Essentials mapping with automated evidence |

## Security Pipeline Stages

1. Pre-commit hooks (Gitleaks secret scanning)
2. SAST — CodeQL static analysis
3. SCA — Trivy dependency scanning (API + Frontend in parallel)
4. SBOM generation — Syft (CycloneDX format)
5. Container image scanning — Trivy
6. IaC scanning — Checkov for Terraform and Kubernetes
7. Policy-as-code — OPA/Conftest custom policies
8. Security quality gate — pass/fail on severity thresholds
9. DAST — OWASP ZAP baseline scan against running application

## Key Enterprise Patterns

- **OIDC authentication** — GitHub Actions to AWS with short-lived tokens (zero static keys)
- **Reusable composite actions** — security scans packaged as modular, pluggable actions any team can adopt
- **Terraform modules** — VPC, EKS, and security resources as independent, reusable modules
- **Environment separation** — staging and production namespaces with separate configs
- **Branch protection** — PRs required, security checks must pass, no direct push to main
- **Image integrity** — immutable tags, private ECR registry, SBOM for every build
- **Policy-as-code** — OPA/Conftest for Terraform, Kyverno admission controller for Kubernetes
- **Detection-as-code** — Sigma rules for attack pattern detection (brute force, SQLi, privilege escalation)
- **Automated response (SOAR)** — GuardDuty → EventBridge → Lambda (credential revocation, instance isolation)
- **Docker layer caching** — multi-stage builds with dependency caching for fast CI
- **Security metrics** — Grafana dashboards tracking MTTR, scan pass rate, time-to-feedback

## Compliance Mapping

Every security control maps to at least one framework requirement:

| Framework | Coverage |
|-----------|----------|
| ISO 27001:2022 | 14 Annex A controls mapped to pipeline and infrastructure controls |
| SOC 2 Type II | 15 Trust Services Criteria mapped to automated evidence collection |
| NIST CSF 2.0 | All 6 functions covered: Identify, Protect, Detect, Respond, Recover, Govern |
| OWASP Top 10 (2021) | All 10 categories addressed via SAST, DAST, SCA, and secure coding |
| OWASP LLM Top 10 | Prompt injection, data leakage, and model abuse demonstrated and mitigated |
| Cyber Essentials Plus | All 5 technical controls demonstrated |

## Project Structure

    securestack-platform/
    ├── app/                                    # Application code (3-tier)
    │   ├── frontend/                           # React SPA with Nginx
    │   │   ├── Dockerfile                      # Multi-stage build, non-root, security headers
    │   │   ├── default.conf                    # Nginx config with CSP, HSTS, X-Frame-Options
    │   │   └── src/                            # React source code
    │   ├── api/                                # Node.js REST API
    │   │   ├── Dockerfile                      # Multi-stage build, non-root, health check
    │   │   ├── app.js                          # Express server with auth, search, AI routes
    │   │   ├── routes/
    │   │   │   ├── authRoutes.js               # JWT authentication (register, login)
    │   │   │   ├── userRoutes.js               # CRUD with RBAC (admin/viewer roles)
    │   │   │   ├── searchRoutes.js             # DELIBERATELY VULNERABLE — SQL injection demo
    │   │   │   └── aiRoutes.js                 # AI endpoints — vulnerable + secure with guardrails
    │   │   ├── controllers/                    # Business logic
    │   │   ├── middleware/                      # JWT verification, role-based access
    │   │   ├── models/                         # MySQL connection pool
    │   │   └── .env.example                    # Environment variable template (no secrets)
    │   └── db/
    │       └── init.sql                        # MySQL schema initialisation
    │
    ├── .github/
    │   ├── workflows/
    │   │   └── ci-security.yml                 # Main CI pipeline — 8 parallel security stages
    │   └── actions/                            # Reusable composite actions (modular security)
    │       ├── gitleaks-scan/action.yml         # Secret scanning
    │       ├── codeql-sast/action.yml           # Static application security testing
    │       ├── trivy-scan/action.yml            # SCA + container image scanning
    │       ├── checkov-iac/action.yml            # Infrastructure-as-code scanning
    │       ├── sbom-generate/action.yml         # Software bill of materials generation
    │       ├── zap-dast/action.yml              # Dynamic application security testing
    │       └── conftest-policy/action.yml       # OPA/Conftest policy validation
    │
    ├── terraform/
    │   ├── main.tf                             # Root module — orchestrates VPC, EKS, Security
    │   ├── variables.tf                        # Input variables with sensible defaults
    │   ├── outputs.tf                          # Infrastructure outputs for CI/CD consumption
    │   └── modules/
    │       ├── vpc/                            # VPC with public/private subnets, NAT, flow logs
    │       ├── eks/                            # EKS cluster with KMS encryption, OIDC, audit logs
    │       └── security/                       # GuardDuty, CloudTrail, Security Hub, ECR, Secrets Manager
    │
    ├── k8s/
    │   ├── base/
    │   │   ├── namespace.yaml                  # Staging + production with PSS restricted
    │   │   ├── deployments.yaml                # Hardened pods: non-root, read-only fs, dropped caps
    │   │   ├── network-policies.yaml           # Zero-trust: default deny + explicit allow rules
    │   │   ├── rbac.yaml                       # Least-privilege service accounts with named resources
    │   │   ├── kyverno-policies.yaml           # 6 admission policies (no root, no privileged, registry restrict)
    │   │   └── external-secrets.yaml           # AWS Secrets Manager to K8s secret sync
    │   ├── staging/                            # Staging environment overrides
    │   └── production/                         # Production environment overrides
    │
    ├── security/
    │   ├── policies/
    │   │   ├── opa/
    │   │   │   └── terraform.rego              # 6 custom OPA policies (tagging, encryption, SG, IAM)
    │   │   └── kyverno/                        # Kyverno policy overrides
    │   ├── sigma-rules/
    │   │   ├── brute-force-login.yml           # T1110 — credential stuffing detection
    │   │   ├── sql-injection-attempt.yml       # T1190 — injection pattern detection
    │   │   ├── privilege-escalation.yml        # T1078 — unauthorised admin access attempts
    │   │   └── aws-root-account-usage.yml      # T1078.004 — root account monitoring
    │   └── docs/
    │       ├── threat-model.md                 # STRIDE analysis with MITRE ATT&CK mapping
    │       ├── compliance-mapping.md           # ISO 27001, SOC 2, NIST CSF, OWASP, Cyber Essentials
    │       ├── incident-response-runbook.md    # NIST 800-61 based IR with GDPR notification timelines
    │       └── llm-security.md                 # OWASP LLM Top 10 assessment
    │
    ├── monitoring/
    │   ├── prometheus/
    │   │   ├── prometheus.yml                  # Scrape configs for API, K8s nodes, kube-state-metrics
    │   │   └── alert-rules.yml                 # Security alerts: brute force, exfiltration, crash loops
    │   └── grafana/
    │       └── security-dashboard.json         # 10-panel SecOps dashboard (MTTR, pass rate, error rate)
    │
    ├── scripts/
    │   ├── setup-secrets.sh                    # One-time AWS Secrets Manager initialisation
    │   └── soar-auto-response.py              # Lambda: auto-revoke credentials, isolate instances
    │
    ├── docs/
    │   └── developer-security-guide.md         # Onboarding guide: secure coding, pipeline, secrets
    │
    ├── docker-compose.yaml                     # Local development with health checks and networking
    ├── .checkov.yaml                           # IaC scan config with documented risk acceptances
    ├── .gitignore                              # Prevents secrets, state files, and builds from being committed
    └── README.md                               # This file

## Security Vulnerabilities (Deliberate)

This project contains deliberate vulnerabilities for demonstration purposes:

| Vulnerability | Location | OWASP Category | Detection Tool |
|--------------|----------|---------------|---------------|
| SQL Injection | `app/api/routes/searchRoutes.js` | A03: Injection | CodeQL (SAST) + ZAP (DAST) |
| Hardcoded JWT Secret | `app/api/middleware/auth.js` | A02: Cryptographic Failures | Gitleaks |
| Information Disclosure | `app/api/routes/searchRoutes.js` | A01: Broken Access Control | ZAP (DAST) |
| SSL Verification Disabled | `app/api/models/db.js` | A07: Security Misconfiguration | CodeQL (SAST) |
| Open CORS | `app/api/app.js` | A05: Security Misconfiguration | ZAP (DAST) |
| Prompt Injection | `app/api/routes/aiRoutes.js` | LLM01: Prompt Injection | Manual + secure endpoint comparison |
| Data Leakage via LLM | `app/api/routes/aiRoutes.js` | LLM06: Sensitive Info Disclosure | Manual + secure endpoint comparison |

## Certifications & Background

Built by [Bakary Sillah](https://linkedin.com/in/) — CompTIA Security+, AWS Cloud Practitioner, HashiCorp Terraform Associate, Google Cybersecurity Certificate.


## License

MIT
