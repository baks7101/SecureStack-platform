# CLAUDE.md — AI Agent Governance for SecureStack

This repository is the security tooling and control plane for the SecureStack
platform: reusable CI/CD pipelines, detection rules, policies, and governance
scripts that other repositories depend on. Changes here affect the security
posture of every repo that calls these workflows. AI coding agents working in
this repo must follow the rules below.

## Why this file exists

SecureStack enforces a CLAUDE.md governance check on the repos it scans, so it
must meet that standard itself. More importantly, an agent editing security
controls can weaken them in ways that are easy to miss, so the guardrails here
are stricter than for an ordinary application repo.

## Rules for AI agents

### Never weaken a control to make a pipeline pass
Do not disable, skip, loosen, or add `|| true` to a security stage, rule, or
gate in order to get a green run. A failing security check is information, not
an obstacle. If a control is wrong, fix the control deliberately and explain
why; never silence it.

### Never edit gate logic without checking both directions
The security gate must fail when a required stage fails and pass when all
required stages pass. Any change to gate evaluation, `needs:` lists, or result
handling must be reasoned through for both the passing and failing case before
it is applied. Silent gate bugs are the highest-risk change in this repo.

### Do not touch detection rules to suppress a specific finding
Semgrep rules, policies, and validators exist to catch real issues. Do not
narrow a rule, add an exclusion, or adjust a severity threshold to make one
finding disappear. Tune rules only to fix genuine false positives or false
negatives, with the reasoning recorded.

### Never commit secrets
No credentials, API keys, tokens, or private keys in any file, including
example configs, test fixtures, or workflow files. Use GitHub secrets and
reference them via `${{ secrets.NAME }}`. Assume anything committed is public
forever.

### Pass untrusted input through env, not inline interpolation
In workflows, never interpolate `${{ github.* }}` values directly into a shell
script. Pass them as environment variables so a crafted branch or actor name
cannot inject shell commands.

### Verify before assuming, and show your work
Do not claim a control works without testing it. Prefer editing files with a
match count or a view-before-edit step over blind string replacement,
especially in the reusable workflow. Validate YAML after any workflow change.

### Do not add tools without justification
New scanners or stages must earn their place by catching something existing
stages cannot, and must be verified to actually detect before being made a
blocking gate. A control that passes without doing anything is worse than no
control.

## Scope

These rules apply to all agent activity in this repository: slash commands,
packaged skills, MCP tool calls, and direct file edits. When in doubt, choose
the option that keeps a security control honest rather than convenient.
