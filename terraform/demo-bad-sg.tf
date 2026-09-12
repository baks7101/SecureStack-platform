# DEMO: deliberately insecure security group to show OPA Rule 3 catching it.
# Opens SSH (port 22) to the entire internet (0.0.0.0/0) — a classic misconfig.
resource "aws_security_group" "demo_bad" {
  name        = "demo-bad-sg"
  description = "Demo SG that violates OPA policy (SSH open to the world)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from anywhere (VIOLATION)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demo-bad-sg"
  }
}
