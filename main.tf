# configure version of aws provider plugin
# https://developer.hashicorp.com/terraform/language/terraform#terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}

# https://developer.hashicorp.com/terraform/language/values/locals
locals {
  project_name = "lab_week_4"
}

# get the most recent ami for Ubuntu 24.04 owned by amazon
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Create a VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "web" {
  cidr_block           = "10.0.0.0/16"
	# enable dns enable_dns_hostnames

  tags = {
    Name    = ""${local.project_name}_vpc""
		# add project name using local
  }
}

# Create a public subnet
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
# To use the free tier t2.micro ec2 instance you have to declare an AZ
# Some AZs do not support this instance type
resource "aws_subnet" "web" {
  vpc_id                  = aws_vpc.web.id
  cidr_block              = "10.0.1.0/24"
	# set availability zone
	# add public ip on launch

  tags = {
    Name = "${local.project_name}_subnet"
		# add project name using local
  }
}

# Create internet gateway for VPC
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "web-gw" {
	# add vpc

  tags = {
    Name = "${local.project_name}_Web"
		# add project name using local
  }
}

# create route table for web VPC 
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "web" {
	# add vpc 

  tags = {
    Name = "${local.project_name}_web-route"
		# add project name using local
  }
}

# add route to to route table
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.web.id
  destination_cidr_block = "0.0.0.0/0"
	# add gateway id

}

resource "aws_internet_gateway" "web_gw" {
  vpc_id = aws_vpc.web.id

  tags = {
    Name = "${local.project_name}_igw"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "web" {
	# add subnet id
  route_table_id = aws_route_table.web.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "web" {
  name        = "allow_ssh"
  description = "allow ssh from home and work"
	# add vpc id
  vpc_id = aws_vpc.web.id

  tags = {
    Name = "${local.project_name}_Web"
		# add project name using local
  }
}

# Allow ssh
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule
resource "aws_vpc_security_group_ingress_rule" "web-ssh" {
  security_group_id = aws_security_group.web.id

  # allow ssh anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Change this to your IP for security
  }
}

# allow http
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule
resource "aws_vpc_security_group_ingress_rule" "web-http" {
  security_group_id = aws_security_group.web.id

	# allow http anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# allow all out
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule
resource "aws_vpc_security_group_egress_rule" "web-egress" {
  security_group_id = aws_security_group.web.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project_name}_sg"
  }
}

# use an existing key pair on host machine with file func
# if we weren't adding the public key in the cloud-init script we could import a public 
# using the aws_key_pair resource block
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair
resource "aws_key_pair" "local_key" {
  key_name   = "web-key"
  public_key = file("/Users/aaronarcalas/Library/Mobile Documents/com~apple~CloudDocs/CIT/4000/4640/Week-4/aws-key/aws-wk4-key.pub")

  tags = {
    Name = "${local.project_name}_key"
  }
}

# create the ec2 instance
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
resource "aws_instance" "web" {
	# use ami provided by data block above
  ami           = data.aws_ami.ubuntu.id
  # set instance type
  instance_type = "t2.micro"
	# add user datat for cloud-config file in scripts directory
  key_name      = aws_key_pair.web_key.key_name
	# add vpc security group 
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = aws_subnet.web.id

  tags = {
    Name = "${local.project_name}_ec2"
		# add project name using local
  }
}

# print public ip and dns to terminal
# https://developer.hashicorp.com/terraform/language/values/outputs
output "instance_ip_addr" {
  description = "The public IP and dns of the web ec2 instance."
  value = {
    "public_ip" = aws_instance.web.public_ip
    "dns_name"  = aws_instance.web.public_dns
  }
}

