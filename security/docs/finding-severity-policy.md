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

## Relationship to the incident response runbook

This document does not define its own severity scale. It uses the Critical / High /
Medium / Low levels and response times already defined in `incident-response-runbook.md`,
and maps specific pipeline and runtime findings onto them.

The runbook answers "an incident is happening, what do I do?". This answers "a finding
just appeared, how serious is it?". A finding may or may not become an incident.

| Level | Response time (from the runbook) | Action on a finding |
|---|---|---|
| **Critical** | Immediate, under 15 minutes | Contain first, then investigate |
| **High** | Under 1 hour | Block the merge, fix before release |
| **Medium** | Under 4 hours | Ticket it, fix in normal flow |
| **Low** | Next business day | Batch with similar work |

## Pipeline finding severities

| Stage | Finding | Severity | Reasoning |
|---|---|---|---|
| 1 Gitleaks | Any real secret committed | **Critical** | A pushed secret is live the moment it is pushed. Deleting the commit does not un-leak it |
| 1 Gitleaks | Test or fake credential | Low | No live exposure, but tune the rule so it stops crying wolf |
| 2 CodeQL / 3 Semgrep | ERROR severity on a reachable path | **High** | Real vulnerability, caught before release |
| 3 Semgrep | ERROR on unreachable or test code | Medium | Fix it, but it is not exploitable as written |
| 4 Trivy SCA | CRITICAL or HIGH, reachable, fix available | **High** | Patch and move on |
| 4 Trivy SCA | CRITICAL or HIGH, no fix available | Medium | Document the accepted risk with a review date |
| 4 Trivy SCA | Dev-only dependency | Medium | Never reaches production |
| 6 Checkov | Public exposure, e.g. open SSH, public bucket | **High** | Would be Critical if it had already been applied |
| 6 Checkov | Missing tags, logging, or similar | Low | Hygiene |
| 7 Trivy image | CRITICAL in a base layer | **High** | Rebuild on a patched base |
| 10 AI-BOM | Unapproved model, framework, or MCP server | **High** | Governance breach. Blocks merge, needs a human decision, not a rubber stamp |
| 5 / 8 / 9 | Unpinned dependency, missing CLAUDE.md, skill findings | Low | Policy and hygiene |

## Runtime finding severities

| Source | Finding | Severity | Reasoning |
|---|---|---|---|
| GuardDuty | Credential compromise, crypto mining | **Critical** | Active attacker or active cost |
| Falco | Shell spawned in a container, unexplained | **Critical** | Classic post-compromise move |
| Falco | Shell spawned, matches a known deploy or debug session | Low | Verify who and why, then close |
| LLM-Guard | Sustained block rate above baseline | **High** | A campaign, not a one-off probe |
| LLM-Guard | Single blocked injection | Low | The control worked. Log it, watch for a pattern |
| LLM-Guard | Rising `llm_guard_errors_total` | **Critical** | Under fail-closed this is a live outage: real requests are being rejected |
| Gatekeeper | Admission block | Medium | Prevention worked. Talk to the developer, this is usually a conversation not an incident |
| App metrics | Auth failure rate spike, single source | Medium | Rate limiting should hold. Watch for success |
| App metrics | Auth failure rate spike, distributed | **High** | Blocking one IP will not help |

## Escalation

- **Critical** goes straight to the channel with a human paged. Contain first, understand second.
- **High** blocks the merge or the release. It does not wait for a sprint boundary.
- **Medium and Low** go through normal ticketing.

## Anything that fails open

If a security control itself fails, treat it as **Critical regardless of what it was protecting**.
A scanner that has silently stopped scanning produces the same green pipeline as a clean
run, and everyone downstream believes it. Absence of alerts is not evidence of absence.
