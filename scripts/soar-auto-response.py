"""
SecureStack SOAR — Automated Incident Response
Triggered by EventBridge when GuardDuty detects a medium+ severity finding.

This Lambda function handles three response scenarios:
1. Compromised IAM credentials — automatically disables the access key
2. Compromised EC2 instance — isolates it by replacing its security group
3. All findings — logs to CloudWatch, sends SNS notification with context

Why automate this?
- Human response at 3am takes 30-60 minutes (wake up, VPN in, assess, act)
- Automated response takes 3 seconds
- Every minute of delayed response increases blast radius

Business impact:
- Automated credential revocation prevents lateral movement
- Automated instance isolation contains the breach to one resource
- SNS notification ensures humans are informed for follow-up investigation
"""

import json
import boto3
import os
from datetime import datetime

ec2 = boto3.client('ec2')
iam = boto3.client('iam')
sns = boto3.client('sns')

SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
ISOLATION_SG_ID = os.environ.get('ISOLATION_SG_ID')


def handler(event, context):
    """Main Lambda handler — routes GuardDuty findings to appropriate response."""

    finding = event.get('detail', {})
    finding_type = finding.get('type', 'Unknown')
    severity = finding.get('severity', 0)
    account_id = finding.get('accountId', 'Unknown')
    region = finding.get('region', 'Unknown')
    description = finding.get('description', 'No description')

    print(f"[SOAR] Processing finding: {finding_type} (severity: {severity})")

    response_actions = []

    # SCENARIO 1: Compromised IAM credentials
    # GuardDuty finding types: UnauthorizedAccess:IAMUser/*, Recon:IAMUser/*
    if 'IAMUser' in finding_type or 'AccessKey' in finding_type:
        result = respond_to_iam_compromise(finding)
        response_actions.append(result)

    # SCENARIO 2: Compromised EC2 instance
    # GuardDuty finding types: Backdoor:EC2/*, CryptoCurrency:EC2/*, Trojan:EC2/*
    if 'EC2' in finding_type:
        result = respond_to_ec2_compromise(finding)
        response_actions.append(result)

    # ALL FINDINGS: Send notification with context
    notify_security_team(
        finding_type=finding_type,
        severity=severity,
        description=description,
        actions_taken=response_actions,
        account_id=account_id,
        region=region
    )

    return {
        'statusCode': 200,
        'finding_type': finding_type,
        'severity': severity,
        'actions_taken': response_actions
    }


def respond_to_iam_compromise(finding):
    """
    Disable compromised IAM access keys.

    Why: A compromised access key can be used to access any AWS resource
    the key's user has permissions for. Disabling it immediately stops
    the attacker from making further API calls.

    What happens next: The security team investigates which actions the
    attacker performed using CloudTrail, rotates credentials, and
    re-enables access with new keys if the user is legitimate.
    """
    try:
        resource = finding.get('resource', {})
        access_key_id = resource.get('accessKeyDetails', {}).get('accessKeyId')
        username = resource.get('accessKeyDetails', {}).get('userName')

        if access_key_id and username:
            iam.update_access_key(
                UserName=username,
                AccessKeyId=access_key_id,
                Status='Inactive'
            )
            action = f"Disabled access key {access_key_id} for user {username}"
            print(f"[SOAR] {action}")
            return action
        else:
            return "IAM finding but no access key details found"

    except Exception as e:
        error = f"Failed to disable access key: {str(e)}"
        print(f"[SOAR] ERROR: {error}")
        return error


def respond_to_ec2_compromise(finding):
    """
    Isolate compromised EC2 instance by replacing its security groups.

    Why: An isolated instance can't communicate with other resources,
    stopping lateral movement. But it stays running so forensic evidence
    (memory, processes, network connections) is preserved.

    What happens next: The security team connects via SSM Session Manager
    (which bypasses security groups) to investigate, captures a disk
    snapshot for forensics, then terminates the instance.
    """
    try:
        resource = finding.get('resource', {})
        instance_id = resource.get('instanceDetails', {}).get('instanceId')

        if instance_id and ISOLATION_SG_ID:
            ec2.modify_instance_attribute(
                InstanceId=instance_id,
                Groups=[ISOLATION_SG_ID]
            )
            action = f"Isolated instance {instance_id} with security group {ISOLATION_SG_ID}"
            print(f"[SOAR] {action}")
            return action
        else:
            return "EC2 finding but no instance ID or isolation SG configured"

    except Exception as e:
        error = f"Failed to isolate instance: {str(e)}"
        print(f"[SOAR] ERROR: {error}")
        return error


def notify_security_team(finding_type, severity, description, actions_taken, account_id, region):
    """
    Send structured notification to the security team via SNS.

    Why structured: At 3am, the on-call engineer needs to understand
    the situation in 10 seconds. Severity, what happened, what was
    done automatically, and what they need to do next.
    """
    try:
        severity_label = 'CRITICAL' if severity >= 7 else 'HIGH' if severity >= 4 else 'MEDIUM'

        message = f"""
============================================
  SECURESTACK SECURITY ALERT — {severity_label}
============================================

Finding:     {finding_type}
Severity:    {severity}/10 ({severity_label})
Account:     {account_id}
Region:      {region}
Time:        {datetime.utcnow().isoformat()}Z

Description:
{description}

Automated Actions Taken:
{chr(10).join(f'  - {a}' for a in actions_taken) if actions_taken else '  - Notification only (no automated action matched)'}

Required Human Actions:
  1. Assess the finding in GuardDuty console
  2. Review CloudTrail for related activity
  3. Determine if escalation to incident response is needed
  4. Document findings in incident tracker

Dashboard: https://console.aws.amazon.com/guardduty
Runbook:   https://github.com/baks7101/securestack-platform/security/docs

============================================
"""

        if SNS_TOPIC_ARN:
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=f"[{severity_label}] SecureStack Alert: {finding_type}",
                Message=message
            )
            print(f"[SOAR] Notification sent to SNS")
        else:
            print(f"[SOAR] SNS_TOPIC_ARN not configured — logging only")
            print(message)

    except Exception as e:
        print(f"[SOAR] ERROR sending notification: {str(e)}")
"""
Deployment note:
This Lambda is deployed via Terraform in the security module.
Environment variables (SNS_TOPIC_ARN, ISOLATION_SG_ID) are set in Terraform.
The EventBridge rule triggers this function on GuardDuty findings with severity >= 4.
"""
