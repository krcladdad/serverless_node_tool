terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# -------------------------------
# 1) IAM Role EC2 can assume
# -------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2-secrets-read-role"

  # Trust policy: allow EC2 to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# -------------------------------
# 2) Least-privilege policy for your secret ARN
# -------------------------------
resource "aws_iam_policy" "secrets_read_only" {
  name        = "ec2-secrets-read-only"
  description = "Allow EC2 to read only specific Secrets Manager secret"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = var.secret_arn
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "attach_read_only" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_read_only.arn
}

# -------------------------------
# 3) Instance profile wrapping the role
# -------------------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-secrets-read-profile"
  role = aws_iam_role.ec2_role.name
}

# -------------------------------
# 4) Attach instance profile to your EC2
# -------------------------------
# Tip: resolve AL2 AMI per region (avoid hard-coded AMI IDs)
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# -------------------------------
# Security Group
# -------------------------------
resource "aws_security_group" "flask_sg" {
  name        = "flask_sg"
  description = "Allow HTTP, SSH, and Flask port"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask App"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Alternate HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flask_sg"
  }
}

# Generate SSH key pair for EC2 instance
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "aws_instance" "flask_serverless_app" {
  ami                    = data.aws_ami.al2.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.flask_sg.id]

  # 🔹 Attach the instance profile created above
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              set -euo pipefail
              export AWS_DEFAULT_REGION="${var.region}"

              yum update -y
              yum install -y docker jq unzip curl

              # Install AWS CLI v2
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip -q awscliv2.zip
              ./aws/install

              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user

              # Fetch secret by ARN (uses role credentials automatically)
              SECRET_JSON=$(aws secretsmanager get-secret-value \
                --secret-id "${var.secret_arn}" \
                --query SecretString --output text)

              USERNAME=$(echo "$SECRET_JSON" | jq -r .DOCKER_USERNAME)
              PASSWORD=$(echo "$SECRET_JSON" | jq -r .DOCKER_PASSWORD)

              echo "$PASSWORD" | sudo docker login -u "$USERNAME" --password-stdin
              sudo docker pull "$USERNAME/flask-app:latest"
              sudo docker run --restart=always -d -p 5000:5000 --name flask-app "$USERNAME/flask-app:latest"
              EOF

}

# -------------------------------
# 5) (Optional) Resource-based policy on the secret
#     This lets the secret itself explicitly allow the role.
#     Useful in multi-account or stricter setups.
# -------------------------------
resource "aws_secretsmanager_secret_policy" "allow_role_read" {
  secret_arn = var.secret_arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowEC2RoleGetSecret",
        Effect    = "Allow",
        Principal = { AWS = aws_iam_role.ec2_role.arn },
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = var.secret_arn
      }
    ]
  })
}