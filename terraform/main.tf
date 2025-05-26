provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# VPC
resource "aws_vpc" "ipfs_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "ipfs-vpc"
    }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.ipfs_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.ipfs_vpc.id
  cidr_block = "10.0.2.0/24"
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.ipfs_vpc.id
}

# Route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.ipfs_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  depends_on = [aws_internet_gateway.gw]
}

# NAT Gateway in public subnet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.gw]
}

# Route table for private subnet (uses NAT)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.ipfs_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Bastion SG
resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Allow SSH to bastion host"
  vpc_id      = aws_vpc.ipfs_vpc.id

  ingress {
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
}

# Private Node SG
resource "aws_security_group" "private_node_sg" {
  name        = "private_node_sg"
  description = "Allow IPFS and app traffic internally"
  vpc_id      = aws_vpc.ipfs_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 4001
    to_port     = 4001
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Bastion Host (FIXED: vpc_security_group_ids instead of security_groups)
resource "aws_instance" "bastion" {
  ami                         = "ami-084568db4383264d4"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  key_name                    = "ipfs-key"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "bastion-host"
  }
}

# Private Nodes (IPFS + Node.js)
resource "aws_instance" "private_nodes" {
  count                       = 5
  ami                         = "ami-084568db4383264d4"
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.private.id
  key_name                    = "ipfs-key"
  vpc_security_group_ids      = [aws_security_group.private_node_sg.id]
  associate_public_ip_address = false
  tags = {
    Name = "private-node-${count.index + 1}"
  }
}
