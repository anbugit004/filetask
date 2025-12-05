terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------
# Providers for 2 regions
# ---------------------------
provider "aws" {
  region = "ap-south-1"
  alias  = "mumbai"
}

provider "aws" {
  region = "us-west-1"
  alias  = "california"
}

# ---------------------------
# Lookup Latest Ubuntu AMIs (NO MORE ERRORS!)
# ---------------------------
data "aws_ami" "ubuntu_mumbai" {
  provider      = aws.mumbai
  most_recent   = true
  owners        = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_ami" "ubuntu_california" {
  provider      = aws.california
  most_recent   = true
  owners        = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ---------------------------
# Mumbai VPC + Subnet + IGW
# ---------------------------
resource "aws_vpc" "mumbai_vpc" {
  provider   = aws.mumbai
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "mumbai_igw" {
  provider = aws.mumbai
  vpc_id   = aws_vpc.mumbai_vpc.id
}

resource "aws_subnet" "mumbai_public" {
  provider                = aws.mumbai
  vpc_id                  = aws_vpc.mumbai_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
}

resource "aws_route_table" "mumbai_rt" {
  provider = aws.mumbai
  vpc_id   = aws_vpc.mumbai_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mumbai_igw.id
  }
}

resource "aws_route_table_association" "mumbai_rt_assoc" {
  provider       = aws.mumbai
  route_table_id = aws_route_table.mumbai_rt.id
  subnet_id      = aws_subnet.mumbai_public.id
}

# ---------------------------
# California VPC + Subnet + IGW
# ---------------------------
resource "aws_vpc" "california_vpc" {
  provider   = aws.california
  cidr_block = "10.2.0.0/16"
}

resource "aws_internet_gateway" "california_igw" {
  provider = aws.california
  vpc_id   = aws_vpc.california_vpc.id
}

resource "aws_subnet" "california_public" {
  provider                = aws.california
  vpc_id                  = aws_vpc.california_vpc.id
  cidr_block              = "10.2.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-1a"  # VALID AZ
}

resource "aws_route_table" "california_rt" {
  provider = aws.california
  vpc_id   = aws_vpc.california_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.california_igw.id
  }
}

resource "aws_route_table_association" "california_rt_assoc" {
  provider       = aws.california
  route_table_id = aws_route_table.california_rt.id
  subnet_id      = aws_subnet.california_public.id
}

# ---------------------------
# Security Groups
# ---------------------------
resource "aws_security_group" "mumbai_sg" {
  provider = aws.mumbai
  name     = "mumbai-nginx-sg"
  vpc_id   = aws_vpc.mumbai_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "california_sg" {
  provider = aws.california
  name     = "california-nginx-sg"
  vpc_id   = aws_vpc.california_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------
# Mumbai EC2 (Ubuntu + NGINX)
# ---------------------------
resource "aws_instance" "mumbai" {
  provider      = aws.mumbai
  ami           = data.aws_ami.ubuntu_mumbai.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.mumbai_public.id
  key_name      = "demo-key-pair"
  vpc_security_group_ids = [aws_security_group.mumbai_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install nginx -y
    systemctl enable nginx
    systemctl start nginx
  EOF

  tags = {
    Name = "Mumbai-Ubuntu-Nginx"
  }
}

# ---------------------------
# California EC2 (Ubuntu + NGINX)
# ---------------------------
resource "aws_instance" "california" {
  provider      = aws.california
  ami           = data.aws_ami.ubuntu_california.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.california_public.id
  key_name      = "demo-key-pair"
  vpc_security_group_ids = [aws_security_group.california_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install nginx -y
    systemctl enable nginx
    systemctl start nginx
  EOF

  tags = {
    Name = "California-Ubuntu-Nginx"
  }
}

# Outputs
output "mumbai_public_ip" {
  value = aws_instance.mumbai.public_ip
}

output "california_public_ip" {
  value = aws_instance.california.public_ip
}
