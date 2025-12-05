terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider for ap-south-1 (Mumbai)
provider "aws" {
  region = "ap-south-1"
}

# Provider for us-west-1 (California)
provider "aws" {
  alias  = "california"
  region = "us-west-1"
}

########################################
# Mumbai default VPC + subnet + SG
########################################

data "aws_vpc" "mumbai" {
  default = true
}

data "aws_subnets" "mumbai" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.mumbai.id]
  }
}

data "aws_security_group" "mumbai_default" {
  filter {
    name   = "group-name"
    values = ["default"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.mumbai.id]
  }
}

########################################
# California default VPC + subnet + SG
########################################

data "aws_vpc" "california" {
  provider = aws.california
  default  = true
}

data "aws_subnets" "california" {
  provider = aws.california
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.california.id]
  }
}

data "aws_security_group" "california_default" {
  provider = aws.california

  filter {
    name   = "group-name"
    values = ["default"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.california.id]
  }
}

########################################
# EC2 Instance in Mumbai
########################################

resource "aws_instance" "mumbai" {
  ami                    = "ami-0ded8326293d3201b"
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnets.mumbai.ids[0]
  vpc_security_group_ids = [data.aws_security_group.mumbai_default.id]

  tags = {
    Name = "Instance-Mumbai"
  }
}

########################################
# EC2 Instance in California
########################################

resource "aws_instance" "california" {
  provider               = aws.california
  ami                    = "ami-03fac5402e10ea93b"
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnets.california.ids[0]
  vpc_security_group_ids = [data.aws_security_group.california_default.id]

  tags = {
    Name = "Instance-California"
  }
}
