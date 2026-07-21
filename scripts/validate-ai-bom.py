#!/usr/bin/env python3
"""Validate a repository ai-bom.json against the security-team approved components list."""

import json
import sys

CLASSIFICATION_RANK = {
    "public": 0,
    "internal": 1,
    "confidential": 2,
    "PII": 3,
    "PHI": 4,
}


def load(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        fail_hard("Missing required file: " + path)
    except json.JSONDecodeError as exc:
        fail_hard("Malformed JSON in " + path + ": " + str(exc))


def fail_hard(message):
    print("AI-BOM VALIDATION FAILED")
    print("  " + message)
    sys.exit(1)


def rank(classification):
    if classification not in CLASSIFICATION_RANK:
        return None
    return CLASSIFICATION_RANK[classification]


def check_models(bom, approved, violations):
    index = {(m["name"], m["provider"]): m for m in approved.get("approvedModels", [])}

    for model in bom.get("models", []):
        key = (model.get("name"), model.get("provider"))

        if key not in index:
            violations.append(
                "Model not approved: " + str(model.get("name"))
                + " (provider: " + str(model.get("provider")) + ")"
            )
            continue

        declared = model.get("dataClassification", "public")
        allowed = index[key].get("maxDataClassification", "public")
        declared_rank, allowed_rank = rank(declared), rank(allowed)

        if declared_rank is None:
            violations.append(
                "Unknown dataClassification '" + str(declared)
                + "' on model " + str(model.get("name"))
            )
        elif allowed_rank is None:
            violations.append(
                "Approved list has unknown maxDataClassification '" + str(allowed)
                + "' for model " + str(model.get("name"))
            )
        elif declared_rank > allowed_rank:
            violations.append(
                "Model " + str(model.get("name")) + " is approved only up to '"
                + allowed + "' data but is declared for '" + declared + "'"
            )


def check_frameworks(bom, approved, violations):
    index = {f["name"]: f for f in approved.get("approvedFrameworks", [])}

    for framework in bom.get("frameworks", []):
        name = framework.get("name")
        version = framework.get("version")

        if name not in index:
            violations.append("Framework not approved: " + str(name))
            continue

        allowed_versions = index[name].get("approvedVersions", [])
        if allowed_versions and version not in allowed_versions:
            violations.append(
                "Framework " + str(name) + " version " + str(version)
                + " not approved (allowed: " + ", ".join(allowed_versions) + ")"
            )


def check_simple_list(bom, approved, bom_key, approved_key, label, violations):
    allowed = {entry["name"] for entry in approved.get(approved_key, [])}

    for entry in bom.get(bom_key, []):
        name = entry.get("name") if isinstance(entry, dict) else entry
        if name not in allowed:
            violations.append(label + " not approved: " + str(name))


def main():
    if len(sys.argv) != 3:
        print("Usage: validate-ai-bom.py <ai-bom.json> <approved-ai-components.json>")
        sys.exit(2)

    bom_path, approved_path = sys.argv[1], sys.argv[2]
    bom = load(bom_path)
    approved = load(approved_path)

    component = bom.get("component", {}).get("name", "unknown")
    print("Validating AI-BOM for: " + component)
    print("Against approved list owned by: " + approved.get("owner", "unknown"))
    print("")

    violations = []
    check_models(bom, approved, violations)
    check_frameworks(bom, approved, violations)
    check_simple_list(bom, approved, "mcpServers", "approvedMcpServers", "MCP server", violations)
    check_simple_list(bom, approved, "agentTools", "approvedAgentTools", "Agent tool", violations)

    declared_counts = (
        str(len(bom.get("models", []))) + " model(s), "
        + str(len(bom.get("frameworks", []))) + " framework(s), "
        + str(len(bom.get("mcpServers", []))) + " MCP server(s), "
        + str(len(bom.get("agentTools", []))) + " agent tool(s)"
    )
    print("Declared: " + declared_counts)
    print("")

    if violations:
        print("AI-BOM VALIDATION FAILED")
        for violation in violations:
            print("  - " + violation)
        print("")
        print("Add the component to security/approved-ai-components.json in SecureStack")
        print("after security review, or remove it from the repository ai-bom.json.")
        sys.exit(1)

    print("AI-BOM VALIDATION PASSED")
    print("All declared AI components are approved.")
    sys.exit(0)


if __name__ == "__main__":
    main()
