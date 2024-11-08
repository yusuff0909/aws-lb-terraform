# configured aws provider with proper credentials
provider "aws" {
  region    = var.region
  profile   = "default" 
}

# create a vpc
resource "aws_vpc" "this" {
  cidr_block = "10.20.20.0/26"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    "Name" = "Application-lb"
  }
}

# create a subnet
resource "aws_subnet" "private" {
  count             = length(var.subnet_cidr_private)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.subnet_cidr_private[count.index]
  availability_zone = var.availability_zone[count.index]
  tags = {
    "Name" = "Application-lb-private"
  }
}

# create a route table
resource "aws_route_table" "this-rt" {
  vpc_id = aws_vpc.this.id
  tags = {
    "Name" = "Application-lb-route-table"
  }
}

# create a route table association
resource "aws_route_table_association" "private" {
  count          = length(var.subnet_cidr_private)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.this-rt.id
}

# create an internet gateway
resource "aws_internet_gateway" "this-igw" {
  vpc_id = aws_vpc.this.id
  tags = {
    "Name" = "Application-lb-gateway"
  }
}

# create an internet route
resource "aws_route" "internet-route" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.this-rt.id
  gateway_id             = aws_internet_gateway.this-igw.id
}

# Create a security group
resource "aws_security_group" "web-server" {
  name        = "allow_http_access"
  description = "allow http traffic from alb"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "traffic from alb"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]

  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = "0"
    protocol    = "-1"
    to_port     = "0"
  }
  tags = {
    "Name" = "web-server-sg"
  }
}

# use data source to get a registered amazon linux 2 ami
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

# launch 2 EC2 instances and install apache 
resource "aws_instance" "web-server" {
  count                  = length(var.subnet_cidr_private)
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.amazon_linux_2.id
  vpc_security_group_ids = [aws_security_group.web-server.id]
  subnet_id              = element(aws_subnet.private.*.id, count.index)
  user_data              = file("install_httpd.sh")
  associate_public_ip_address = true
  tags = {
    Name = "web-server-${count.index + 1}"
  }
  
}
