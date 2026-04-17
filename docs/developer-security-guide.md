# SecureStack — Developer Security Guide

Welcome to the team. This guide explains how security works in our development workflow so you can ship code fast without introducing vulnerabilities.

## The Golden Rule

Security is not a separate step — it is built into every step. You don't need to "do security." The pipeline does it for you. Your job is to write good code and respond to findings.

## Your First Day Workflow

1. Clone the repo: `git clone https://github.com/baks7101/securestack-platform.git`
2. Create a branch from develop: `git checkout -b feature/your-feature develop`
3. Copy the env template: `cp app/api/.env.example app/api/.env` and fill in local values
4. Start the app locally: `docker compose up --build`
5. Make your changes
6. Push and create a PR to develop
7. The pipeline runs automatically — fix any findings before requesting review
8. After approval and all checks pass, merge to develop

## What the Pipeline Checks on Every PR

| Stage | Tool | What It Catches | What To Do If It Fails |
|-------|------|----------------|----------------------|
| Secret Scanning | Gitleaks | Hardcoded passwords, API keys, tokens | Remove the secret, rotate it immediately, use Secrets Manager |
| SAST | CodeQL | SQL injection, XSS, command injection in code | Fix the code pattern — CodeQL links to the exact line and suggests a fix |
| SCA | Trivy | Vulnerable npm packages | Update the package: `npm update PACKAGE` or `npm audit fix` |
| Container Scan | Trivy | Vulnerable OS packages in Docker images | Update the base image or pin a patched version |
| IaC Scan | Checkov | Terraform misconfigurations | Fix the Terraform — Checkov links to documentation for each finding |
| Policy Check | Conftest | Missing tags, encryption, org-specific rules | Read the error message — it explains the policy and why it exists |
| DAST | OWASP ZAP | Runtime vulnerabilities, missing headers | Check the ZAP report artifact for details and remediation guidance |

## Secure Coding Practices

### Do

- Use parameterised queries for ALL database operations
- Validate and sanitise all user input on the server side
- Use environment variables for configuration, never hardcode
- Return generic error messages to clients (not stack traces)
- Use bcrypt or argon2 for password hashing (never MD5 or SHA)
- Set JWT tokens to expire (1 hour max for access tokens)
- Add rate limiting to authentication endpoints

### Do Not

- Never concatenate user input into SQL queries
- Never log sensitive data (passwords, tokens, personal data)
- Never commit .env files, certificates, or private keys
- Never use `eval()` or `exec()` with user input
- Never disable TLS verification (`rejectUnauthorized: false`)
- Never run containers as root
- Never use `latest` tag for Docker images in production

## Responding to Security Findings

When the pipeline flags a finding in your PR:

1. Read the finding — it includes the severity, the exact line, and often a fix suggestion
2. If it is CRITICAL or HIGH — fix it before merging, no exceptions
3. If it is MEDIUM — fix it if quick, or create a ticket and link it in the PR
4. If it is a false positive — add a skip comment with justification and get security team approval
5. If you are unsure — ask in the security channel, do not just suppress the finding

## How Secrets Work

Never put secrets in code, environment files, or K8s manifests. Our flow:
AWS Secrets Manager (encrypted, access-logged)
↓
External Secrets Operator (syncs every hour)
↓
Kubernetes Secret (in-memory, RBAC-controlled)
↓
Pod environment variable (runtime only)
To add a new secret:
1. Store it in AWS Secrets Manager via the setup script
2. Add an ExternalSecret resource in k8s/base/external-secrets.yaml
3. Reference it in your deployment's envFrom
4. Never print or log the secret value

## Branch Strategy

- `main` — production-ready code only, protected, requires PR with passing checks
- `develop` — active development, all PRs target here first
- `feature/*` — your working branches, created from develop
- `hotfix/*` — emergency fixes, created from main

## Getting Help

- Security findings: Post in #security-engineering with the finding ID
- Pipeline issues: Post in #devsecops with the workflow run URL
- Secrets access: Request via the setup-secrets.sh script, never share via Slack/email
