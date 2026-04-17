# SecureStack — STRIDE Threat Model

## System Overview

SecureStack is a 3-tier user management application (React frontend, Node.js API, MySQL database) deployed to AWS EKS with a full DevSecOps security pipeline.

## Data Flow
User → Browser → Nginx (Frontend) → Node.js API → MySQL Database
→ AWS Secrets Manager (credentials)
→ CloudTrail (audit logs)

## STRIDE Analysis

### Spoofing (Impersonating a user or service)

| Threat | Component | Mitigation | Status |
|--------|-----------|-----------|--------|
| Attacker uses stolen credentials to access API | API auth endpoint | JWT with expiry, bcrypt password hashing | Implemented |
| Attacker forges JWT token | API middleware | Strong JWT secret from Secrets Manager (not hardcoded) | Implemented |
| Attacker impersonates the frontend to the API | API CORS config | Restrict CORS to known origins | Planned |
| Container pulls malicious image impersonating official | EKS deployments | Kyverno policy restricts to ECR registry only | Implemented |

### Tampering (Modifying data in transit or at rest)

| Threat | Component | Mitigation | Status |
|--------|-----------|-----------|--------|
| Attacker modifies API requests in transit | Network | HTTPS/TLS termination at ALB | Planned |
| Attacker modifies database records directly | MySQL | Network policies restrict DB access to API only | Implemented |
| Attacker modifies container image after push | ECR | Immutable tags, image signing | Implemented |
| Attacker modifies Terraform state | S3 state bucket | Encryption, versioning, access logging | Implemented |
| Attacker modifies CloudTrail logs | S3 CloudTrail bucket | Log file validation, KMS encryption | Implemented |

### Repudiation (Denying an action was performed)

| Threat | Component | Mitigation | Status |
|--------|-----------|-----------|--------|
| User denies performing an action | API | Application logging with user ID and timestamp | Planned |
| Admin denies deleting a user | API audit trail | CloudTrail logs all API calls with identity | Implemented |
| Attacker covers tracks by deleting logs | CloudTrail | Log file validation, separate S3 bucket with versioning | Implemented |
| Developer denies pushing vulnerable code | GitHub | Git commit signing, PR audit trail, pipeline logs | Implemented |

### Information Disclosure (Exposing data to unauthorised parties)

| Threat | Component | Mitigation | Status |
|--------|-----------|-----------|--------|
| SQL injection exposes user data | Search endpoint | Parameterised queries (fixed version), DAST scanning | Demonstrated |
| Error messages leak internal details | API error handling | Sanitise error responses, remove stack traces | Planned |
| Server headers reveal technology stack | Nginx | server_tokens off, security headers | Implemented |
| Secrets exposed in source code | Git repository | Gitleaks in pipeline, .gitignore, Secrets Manager | Implemented |
| Container environment variables readable | K8s | External Secrets Operator, RBAC on secrets | Implemented |

### Denial of Service (Making the system unavailable)

| Threat | Component | Mitigation | Status |
|--------|-----------|-----------|--------|
| Attacker overwhelms API with requests | API | Rate limiting, WAF, resource limits on pods | Partial |
| Attacker sends large payloads | Nginx | client_max_body_size 1m | Implemented |
| Single pod consumes all cluster resources | EKS | Resource limits enforced by Kyverno | Implemented |
| Attacker crashes pods repeatedly | EKS | Liveness/readiness probes, auto-restart, 2 replicas | Implemented |

### Elevation of Privilege (Gaining higher access than authorised)

| Threat | Component | Mitigation | Status |
|--------|-----------|-----------|--------|
| Viewer user accesses admin endpoints | API | Role-based middleware (isAdmin check) | Implemented |
| Container escapes to host | EKS | Non-root, dropped capabilities, read-only filesystem, PSS restricted | Implemented |
| Pod accesses other pods' secrets | K8s | RBAC with resourceNames, namespace isolation | Implemented |
| Attacker escalates from frontend to database | K8s | Network policies: frontend can only reach API | Implemented |
| Pipeline token used to modify repository | GitHub Actions | Minimal permissions (contents: read only) | Implemented |

## MITRE ATT&CK Mapping

| Technique | ID | Covered By |
|-----------|-----|------------|
| Exploit Public-Facing Application | T1190 | DAST (ZAP), WAF, input validation |
| Valid Accounts | T1078 | MFA (planned), JWT expiry, brute force detection |
| Brute Force | T1110 | Sigma rule, Prometheus alert, rate limiting |
| Container Escape | T1611 | PSS restricted, non-root, dropped capabilities |
| Steal Application Access Token | T1528 | Short-lived JWT, Secrets Manager |
| Unsecured Credentials | T1552 | Gitleaks, External Secrets Operator |
| Data from Cloud Storage | T1530 | S3 encryption, bucket policies, public access block |

## Risk Rating

| Risk | Likelihood | Impact | Rating | Mitigation Status |
|------|-----------|--------|--------|------------------|
| SQL injection on search endpoint | High | Critical | Critical | Demonstrated vulnerable, fix documented |
| Brute force on login | Medium | High | High | Detection in place, rate limiting planned |
| Container escape | Low | Critical | Medium | Multiple controls implemented |
| Secrets in source code | Low | Critical | Medium | Gitleaks + Secrets Manager |
| Data exfiltration via database | Low | Critical | Medium | Network policies + egress monitoring |
