#!/bin/bash
# SecureStack — Initial Secrets Setup
# Run this ONCE when first deploying the infrastructure
# Requires: AWS CLI configured with appropriate IAM permissions
#
# This script stores application secrets in AWS Secrets Manager.
# After this, External Secrets Operator handles all secret delivery to K8s.
# Never store these values in Git, CI/CD variables, or local files.

set -euo pipefail

PROJECT="securestack"
REGION="eu-west-2"

echo "============================================"
echo "  SecureStack — Secrets Initialisation"
echo "============================================"
echo ""
echo "This will create secrets in AWS Secrets Manager."
echo "You will be prompted for each value."
echo ""

# Database credentials
read -p "Enter database username [securestack_app]: " DB_USER
DB_USER=${DB_USER:-securestack_app}

read -sp "Enter database password: " DB_PASS
echo ""

read -p "Enter database host [mysql.securestack-production.svc.cluster.local]: " DB_HOST
DB_HOST=${DB_HOST:-mysql.securestack-production.svc.cluster.local}

read -p "Enter database name [crud_app]: " DB_NAME
DB_NAME=${DB_NAME:-crud_app}

read -sp "Enter database root password: " DB_ROOT_PASS
echo ""

echo ""
echo "Storing database credentials..."
aws secretsmanager put-secret-value \
  --region "$REGION" \
  --secret-id "$PROJECT/db-credentials" \
  --secret-string "{
    \"username\": \"$DB_USER\",
    \"password\": \"$DB_PASS\",
    \"host\": \"$DB_HOST\",
    \"database\": \"$DB_NAME\",
    \"root_password\": \"$DB_ROOT_PASS\"
  }"
echo "Database credentials stored."

# JWT secret — generate a strong random value
JWT_SECRET=$(openssl rand -base64 48)
echo ""
echo "Generating and storing JWT secret..."
aws secretsmanager put-secret-value \
  --region "$REGION" \
  --secret-id "$PROJECT/jwt-secret" \
  --secret-string "{\"secret\": \"$JWT_SECRET\"}"
echo "JWT secret stored."

echo ""
echo "============================================"
echo "  All secrets stored successfully"
echo "============================================"
echo ""
echo "  Database credentials: $PROJECT/db-credentials"
echo "  JWT secret:           $PROJECT/jwt-secret"
echo ""
echo "  External Secrets Operator will sync these"
echo "  to Kubernetes within the refresh interval."
echo ""
echo "  To rotate a secret, update it in AWS Secrets"
echo "  Manager and ESO will pick up the change."
echo "============================================"
