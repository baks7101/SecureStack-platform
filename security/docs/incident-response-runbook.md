# SecureStack — Incident Response Runbook

## Overview

This runbook defines the step-by-step process for responding to security incidents detected by our monitoring and alerting systems. Based on NIST SP 800-61 (Computer Security Incident Handling Guide).

## Severity Classification

| Severity | Description | Response Time | Example |
|----------|-------------|---------------|---------|
| Critical | Active breach, data exfiltration, or complete service compromise | Immediate (< 15 min) | GuardDuty: IAM credential compromise, SQL injection success |
| High | Attempted breach, significant vulnerability discovered in production | < 1 hour | Brute force attack detected, critical CVE in running container |
| Medium | Policy violation, unusual activity, non-critical vulnerability | < 4 hours | Privilege escalation attempt blocked by RBAC, medium CVE |
| Low | Informational finding, minor misconfiguration | Next business day | Missing optional security header, informational ZAP finding |

## Automated Responses (SOAR)

These actions happen automatically before a human is involved:

| Trigger | Automated Action | Lambda Function |
|---------|-----------------|-----------------|
| GuardDuty: IAM credential compromise | Access key disabled | soar-auto-response.py |
| GuardDuty: EC2 compromise (crypto mining, backdoor) | Instance isolated via security group swap | soar-auto-response.py |
| All medium+ GuardDuty findings | SNS notification to security team | soar-auto-response.py |
| Prometheus: Authentication failure spike | Alert fired to on-call | alert-rules.yml |
| Prometheus: Database unexpected egress | Alert fired to on-call | alert-rules.yml |

## Human Response Procedure

### Phase 1: Detection and Analysis (First 15 minutes)

1. Acknowledge the alert in the notification channel
2. Open the GuardDuty console or Grafana dashboard to assess the finding
3. Determine the severity using the classification table above
4. If Critical or High, proceed immediately to Phase 2
5. If automated response already acted (key disabled, instance isolated), verify the action succeeded

Questions to answer:
- What was compromised? (credential, instance, application, data)
- Is the attack still active?
- What is the blast radius? (single pod, namespace, entire cluster, AWS account)
- Is customer data affected?

### Phase 2: Containment (First 30 minutes)

For IAM credential compromise:
1. Verify the SOAR function disabled the key
2. Check CloudTrail for all actions performed with the compromised credential
3. Revoke any active sessions: `aws iam delete-login-profile --user-name USERNAME`
4. Review IAM policies for lateral movement paths

For application compromise:
1. Scale compromised pods to zero: `kubectl scale deployment NAME --replicas=0 -n securestack-production`
2. Preserve logs before they rotate: `kubectl logs POD_NAME -n securestack-production > /tmp/incident-logs.txt`
3. Check network policy is containing the blast radius
4. Verify other pods are not affected

For data breach:
1. Identify which data was accessed (CloudTrail, application logs)
2. Determine the number of affected records
3. Notify the Data Protection Officer immediately
4. Start the 72-hour GDPR clock (ICO notification deadline)

### Phase 3: Eradication (1-4 hours)

1. Identify the root cause (vulnerability, misconfiguration, stolen credential)
2. Patch the vulnerability or fix the misconfiguration
3. Rotate all potentially compromised credentials
4. Deploy the fix through the normal pipeline (all security checks must pass)
5. Verify the fix addresses the root cause

### Phase 4: Recovery (4-24 hours)

1. Restore normal operations gradually
2. Scale pods back to normal replica count
3. Re-enable disabled credentials with new keys
4. Monitor closely for 24 hours for signs of recurring compromise
5. Verify all security controls are functioning normally

### Phase 5: Lessons Learned (Within 5 business days)

1. Conduct blameless post-incident review
2. Document the timeline: detection → containment → eradication → recovery
3. Identify gaps in detection, response, or prevention
4. Create action items with owners and deadlines
5. Update this runbook with any new procedures
6. Update Sigma rules or Prometheus alerts if detection was slow
7. Share anonymised findings with the engineering team

## Regulatory Notification Requirements

| Regulation | Requirement | Deadline | Who to Notify |
|-----------|-------------|----------|---------------|
| GDPR Article 33 | Notify supervisory authority of personal data breach | 72 hours | ICO (Information Commissioner's Office) |
| GDPR Article 34 | Notify affected individuals if high risk | Without undue delay | Affected customers |
| ISO 27001 A.6.8 | Report information security events | As defined in policy | Internal security team |
| SOC 2 CC7.3 | Execute response procedures | Immediately | Audit team, management |

## Contact List

| Role | Contact | When to Escalate |
|------|---------|-----------------|
| On-call engineer | PagerDuty rotation | All alerts |
| Security lead | security-lead@company.com | All High and Critical |
| Data Protection Officer | dpo@company.com | Any personal data involvement |
| CTO | cto@company.com | Critical severity only |
| Legal | legal@company.com | Regulatory notification required |
| ICO | https://ico.org.uk/make-a-complaint/ | Confirmed personal data breach |
