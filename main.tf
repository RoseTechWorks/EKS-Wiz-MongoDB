# Provider
provider "aws" {
  region  = "us-east-2"
  profile = "happyco"
}

# Existing EKS VPC
data "aws_vpc" "eks_vpc" {
  filter {
    name   = "tag:Name"
    values = ["my-cluster-vpc"]
  }
}

# PUBLIC subnets in EKS VPC (subnets tagged for ELB are public)
data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }

  filter {
    name   = "tag:kubernetes.io/role/elb"
    values = ["1"]
  }
}

# Security Group (intentionally insecure)
resource "aws_security_group" "mongodb_sg" {
  name        = "mongodb_sg"
  description = "MongoDB insecure access"
  vpc_id      = data.aws_vpc.eks_vpc.id

  ingress {
    description = "MongoDB public access"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
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
    Name = "mongodb-sg"
  }
}

# Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# MongoDB EC2 Instance (PUBLIC)
resource "aws_instance" "mongodb" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = data.aws_subnets.public_subnets.ids[0]
  vpc_security_group_ids      = [aws_security_group.mongodb_sg.id]
  associate_public_ip_address = true
  key_name                    = "MASTERLOG"

  iam_instance_profile = aws_iam_instance_profile.mongodb_instance_profile.name

  user_data = file("install_mongodb.sh")

  tags = {
    Name = "MongoDB-server"
  }
}

# Output
output "mongodb_server_ip" {
  value = aws_instance.mongodb.public_ip
}
