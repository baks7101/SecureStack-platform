# Finding Severity and Response Policy

Owner: security team
Purpose: decide in advance how bad each class of finding is and how fast someone must
respond, so triage is a lookup rather than an improvisation.

## Why this exists

Without a written mapping, every alert looks equally urgent and the loudest or most recent
one gets attention rather than the most dangerous. That is how a real credential leak ends
up queued behind a formatting nag.

## The three triage questions

Severity is not the same as urgency. A CRITICAL CVE in a dev-only dependency that never
reaches production is less urgent than a MEDIUM finding on an internet-facing path. Every
finding gets these three questions before it gets a priority:

1. **Is it exploitable in our context?** Is the vulnerable code path actually reachable,
   and is the component internet-facing or internal only?
2. **Is a fix available?** A patched version, a config change, or nothing yet?
3. **What is the blast radius?** What can an attacker reach if they use it?

## Severity levels

| Level | Meaning | Response time | Action |
|---|---|---|---|
| **P1 Critical** | Live exposure right now | Immediately, drop other work | Contain first, then investigate |
| **P2 High** | Exploitable, not yet live | Same working day | Block the merge, fix before release |
| **P3 Medium** | Real weakness, not directly exploitable here | Within the sprint | Ticket it, fix in normal flow |
| **P4 Low** | Hygiene, policy, or maintainability | Backlog | Batch with similar work |

## Pipeline finding severities

| Stage | Finding | Severity | Reasoning |
|---|---|---|---|
| 1 Gitleaks | Any real secret committed | **P1** | A pushed secret is live the moment it is pushed. Deleting the commit does not un-leak it |
| 1 Gitleaks | Test or fake credential | P4 | No live exposure, but tune the rule so it stops crying wolf |
| 2 CodeQL / 3 Semgrep | ERROR severity on a reachable path | **P2** | Real vulnerability, caught before release |
| 3 Semgrep | ERROR on unreachable or test code | P3 | Fix it, but it is not exploitable as written |
| 4 Trivy SCA | CRITICAL or HIGH, reachable, fix available | **P2** | Patch and move on |
| 4 Trivy SCA | CRITICAL or HIGH, no fix available | P3 | Document the accepted risk with a review date |
| 4 Trivy SCA | Dev-only dependency | P3 | Never reaches production |
| 6 Checkov | Public exposure, e.g. open SSH, public bucket | **P2** | Would be P1 if it had already been applied |
| 6 Checkov | Missing tags, logging, or similar | P4 | Hygiene |
| 7 Trivy image | CRITICAL in a base layer | **P2** | Rebuild on a patched base |
| 10 AI-BOM | Unapproved model, framework, or MCP server | **P2** | Governance breach. Blocks merge, needs a human decision, not a rubber stamp |
| 5 / 8 / 9 | Unpinned dependency, missing CLAUDE.md, skill findings | P4 | Policy and hygiene |

## Runtime finding severities

| Source | Finding | Severity | Reasoning |
|---|---|---|---|
| GuardDuty | Credential compromise, crypto mining | **P1** | Active attacker or active cost |
| Falco | Shell spawned in a container, unexplained | **P1** | Classic post-compromise move |
| Falco | Shell spawned, matches a known deploy or debug session | P4 | Verify who and why, then close |
| LLM-Guard | Sustained block rate above baseline | **P2** | A campaign, not a one-off probe |
| LLM-Guard | Single blocked injection | P4 | The control worked. Log it, watch for a pattern |
| LLM-Guard | Rising `llm_guard_errors_total` | **P1** | Under fail-closed this is a live outage: real requests are being rejected |
| Gatekeeper | Admission block | P3 | Prevention worked. Talk to the developer, this is usually a conversation not an incident |
| App metrics | Auth failure rate spike, single source | P3 | Rate limiting should hold. Watch for success |
| App metrics | Auth failure rate spike, distributed | **P2** | Blocking one IP will not help |

## Escalation

- **P1** goes straight to the channel with a human paged. Contain first, understand second.
- **P2** blocks the merge or the release. It does not wait for a sprint boundary.
- **P3 and P4** go through normal ticketing.

## Anything that fails open

If a security control itself fails, treat it as **P1 regardless of what it was protecting**.
A scanner that has silently stopped scanning produces the same green pipeline as a clean
run, and everyone downstream believes it. Absence of alerts is not evidence of absence.
