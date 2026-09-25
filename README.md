# SecureStack Platform

A reusable DevSecOps **platform**: an 11-stage security pipeline, custom policy-as-code, an AI-BOM validator, and the shared cloud identity that consuming applications authenticate through.

Built and operated end to end by a self-taught engineer, and consumed live by a separate showcase app deployed on AWS EKS.

---

## Why this exists

SecureStack began as a single deliberately vulnerable app, a way to learn what real vulnerabilities look like from the inside. Then a more interesting question took over: not "can I spot the vulnerability?" but "how would a security engineer build the platform that catches it, at scale, for many teams at once?"

So it became a **pure platform**: the reusable pipeline, the policies, and the governance the security team owns, consumed by application repositories that own their own code and infrastructure. The application and its live runtime defences live in **[ai-vibecode-lab](https://github.com/baks7101/ai-vibecode-lab)**, which consumes this platform the way a real product team would.

That split, one team owning the controls, product teams inheriting them and unable to weaken them, is "centralised governance, decentralised execution."

---

## What's in this repo

This is a platform repo. It contains **no application and no cluster**, only:

- **`.github/workflows/full-security-scan.yml`** — the reusable, parameterised security pipeline.
- **`.github/actions/`** — composite actions (gitleaks, codeql, semgrep-style custom rules, trivy, checkov, conftest, syft/grype, zap-dast).
- **`security/policies/opa/`** — custom OPA/Rego policies (policy-as-code), each mapped to a real breach class.
- **`security/`** — the security-program docs (STRIDE threat model, severity policy, IR runbook, compliance mapping, Sigma detections).
- **`scripts/validate-ai-bom.py`** — the AI-BOM validator.
- **`terraform/`** — only the shared GitHub OIDC provider + platform role (persistent identity infrastructure).

---

## The 11-stage pipeline

A **reusable** GitHub Actions workflow. Each repo that calls it declares what it is (`has-docker`, `has-terraform`, `has-kubernetes`, `has-ai`, `run-dast`) and the matching stages run. Everything funnels into a **security gate** that blocks the merge if any required stage fails, plus a Slack alert.

| Stage | Tool | Defends against | Enforcement |
|-------|------|-----------------|-------------|
| 1. Secret scanning | Gitleaks (+ GitHub push protection) | Credentials in git | Block |
| 2. SAST | CodeQL | Injection / unsafe data flow | Report → branch protection |
| 3. Semgrep | custom OWASP + OWASP LLM rules | Top-10 and LLM Top-10 patterns | Hard-fail on ERROR |
| 4. SCA | Trivy | Vulnerable dependencies | Fail on High/Critical |
| 5. Dependency pin check | custom | Supply-chain drift | Hard-fail on floating versions |
| 6. IaC scan | Checkov | Cloud misconfiguration | Enforce |
| 6b. OPA policy | conftest (Rego, against a real plan) | Custom Terraform policy | Enforce |
| 7. Container scan | Trivy (Dockerfile config) | Base-image / Dockerfile issues | Report |
| 8. CLAUDE.md check | custom | Ungoverned AI coding agents | Hard-fail |
| 9. AI-BOM validation | custom validator | Shadow AI / data-class violations | Hard-fail |
| 10a/b. SBOM | Syft + Grype (fail High+) | Blind spots / known-vulnerable components | Fail on High+ |
| 10. DAST | OWASP ZAP (app spun up in CI) | Runtime web vulnerabilities | Gate on high-severity |

---

## Design decisions worth noting

- **Truly reusable:** the OIDC role ARN, Dockerfile path, and CodeQL language are all **inputs**, so each consuming repo passes its own. No hardcoded per-repo values.
- **Pinned scanners:** tool versions are pinned (e.g. `checkov==3.3.16`) so a run that passes today doesn't fail tomorrow just because a scanner added rules.
- **Two enforcement models, deliberately:** hard-fail on clear-cut findings (secrets, high CVEs, custom rules); report-and-gate for noisier tools (CodeQL via branch protection).
- **Custom detection lives here:** the Semgrep AI rules and the OPA/Rego policies are authored once in the platform, so every consumer inherits them, governance as code.
- **DAST genuinely runs:** the DAST stage containerises the app + its llm-guard sidecar in the runner, scans with ZAP, and gates on high-severity classes (SQLi, command injection, XSS, path traversal) via a rules file, not a decorative skip.
- **AI-BOM with data-classification ceilings:** the validator enforces not just "is this model approved" but "is it approved for *this sensitivity of data*", e.g. a model approved for internal data is blocked when pointed at PHI.

---

## How a consuming repo uses it

```yaml
jobs:
  full-security:
    uses: baks7101/SecureStack-platform/.github/workflows/full-security-scan.yml@main
    with:
      has-docker: true
      has-terraform: true
      has-kubernetes: true
      has-ai: true
      run-dast: true
      aws-role-arn: <the consuming repo's own OIDC role>
      dockerfile-path: <where its Dockerfile lives>
      codeql-language: <its language>
    secrets: inherit
```

The platform runs a trimmed version of the pipeline **on itself** (`ci-security.yml`) for the checks that apply to a platform repo (secrets, SAST on its Python, Semgrep, SBOM, CLAUDE.md); the docker/terraform/k8s/AI/DAST stages correctly skip because a platform repo has none of those.

---

## Security program documentation

The documentation a real security function produces, not just tooling: a STRIDE threat model, a finding-severity policy (which justifies the pipeline's blocking thresholds), an incident-response runbook, a compliance mapping (SOC 2 / OWASP / NIST), Sigma detections mapped to MITRE ATT&CK, and LLM security notes.

---

## Honest notes

A lab built to production patterns, not production experience inside a company. Where a control is report-only or scoped down for a lab, it is documented as such. The live runtime capabilities (Kubernetes admission control, SIEM centralisation, runtime detection, GitOps, DAST against a live target) are demonstrated in the consuming app repo, on a real cluster that is provisioned per session and torn down.

---

## Related repository

**[ai-vibecode-lab](https://github.com/baks7101/ai-vibecode-lab)** — the self-contained showcase application (an AI patient-triage API demonstrating the OWASP LLM Top 10) that consumes this platform's pipeline, and where the live runtime defences are proven.
