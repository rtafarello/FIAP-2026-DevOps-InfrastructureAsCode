terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------
# Variáveis de Entrada
# ---------------------------------------------------------
variable "aws_region" {
  type        = string
  description = "Região da AWS para o provisionamento"
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "Tipo da instância EC2"
  default     = "t2.micro"
}

variable "environment" {
  type        = string
  description = "Ambiente de deploy (ex: dev, prod)"
  default     = "dev"
}

# ---------------------------------------------------------
# Data Source: Busca da AMI mais recente do Ubuntu 22.04
# ---------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------
# Security Group para o Servidor Web
# ---------------------------------------------------------
resource "aws_security_group" "web_sg" {
  name        = "cicd-web-sg-${var.environment}"
  description = "Security Group gerenciado via esteira de CI/CD"

  ingress {
    description = "Acesso HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Acesso HTTPS publico"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Trafego de saida liberado"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "cicd-web-sg"
    Environment = var.environment
    ManagedBy   = "GitHub-Actions"
  }
}

# ---------------------------------------------------------
# Instância EC2
# ---------------------------------------------------------
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "<h1>TAmbiente dev</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name        = "Servidor-CI-CD-${var.environment}"
    Environment = var.environment
    ManagedBy   = "GitHub-Actions"
  }
}

# ---------------------------------------------------------
# Outputs
# ---------------------------------------------------------
output "instance_id" {
  description = "ID da instância EC2 provisionada"
  value       = aws_instance.web_server.id
}

output "public_ip" {
  description = "IP público do servidor web"
  value       = aws_instance.web_server.public_ip
}

output "web_url" {
  description = "URL HTTP de acesso à aplicação"
  value       = "http://${aws_instance.web_server.public_ip}"
}