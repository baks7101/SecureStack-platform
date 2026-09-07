# DEMO: deliberately insecure S3 bucket to demonstrate Checkov IaC scanning
resource "aws_s3_bucket" "demo_insecure" {
  bucket = "securestack-demo-insecure-bucket"
}

# No encryption, no versioning, no public-access block, no logging.
# Checkov flags all of these as failed checks.
