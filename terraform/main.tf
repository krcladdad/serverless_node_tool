provider "aws" {
  region = var.region
}

 data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

 resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

 resource "aws_key_pair" "generated" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

 data "aws_vpc" "default" {
  default = true
}

 data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

 resource "aws_security_group" "flask_sg" {
  name        = "flask-app-sg"
  description = "Allow SSH, HTTP, HTTPS, 8080 and 5000 (and optionally all inbound)"
  vpc_id      = data.aws_vpc.default.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Alternate HTTP / app ports
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flask-app-sg"
  }
}

# Optional: an explicit rule to open all inbound traffic when requested (useful for quick dev testing)
 resource "aws_security_group_rule" "open_all_inbound" {
  count            = var.open_all_inbound ? 1 : 0
  type             = "ingress"
  security_group_id = aws_security_group.flask_sg.id
  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]
}

resource "aws_instance" "flask_app" {
  ami                           = data.aws_ami.amazon_linux_2.id
  instance_type                 = var.instance_type
  subnet_id                     = data.aws_subnet_ids.default.ids[0]
  associate_public_ip_address   = true
  vpc_security_group_ids        = [aws_security_group.flask_sg.id]
  key_name                      = aws_key_pair.generated.key_name

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo amazon-linux-extras install docker -y
              sudo service docker start
              sudo usermod -a -G docker ec2-user
              docker run -d -p 5000:5000 ${var.docker_image}
              EOF

  tags = {
    Name = "FlaskAppServer"
  }
}

 resource "aws_eip" "flask_eip" {
  instance = aws_instance.flask_app.id
  vpc      = true
}

output "instance_public_ip" {
  value = aws_eip.flask_eip.public_ip
}

output "instance_public_dns" {
  value = aws_instance.flask_app.public_dns
}

output "ssh_private_key_pem" {
  description = "Private key material for ssh (useful in dev). Don't commit state with secrets in it for production."
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}
  