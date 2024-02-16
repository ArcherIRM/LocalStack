resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.stack_name}-VPC"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.stack_name}-IGW"
  }
}

resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.stack_name}-public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.stack_name}-private-subnet"
  }
}


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.stack_name}-private-route-table"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.stack_name}-public-route-table"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "${var.stack_name}-NGW"
  }
}

resource "aws_route" "public_internet_gateway" {
  depends_on = [
    aws_route_table_association.public
  ]
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "private_nat_gateway" {
  depends_on = [
    aws_route_table_association.private
  ]
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "archer_sql_server" {
  name        = "${var.stack_name}-sql-server-sg"
  description = "Archer sql-server security group"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.stack_name}-sql-server-sg"
  }
}

resource "aws_security_group" "archer_ssms" {
  name        = "${var.stack_name}-ssms-sg"
  description = "Archer ssms security group"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.stack_name}-ssms-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "to_sql_server" {
  security_group_id = aws_security_group.archer_sql_server.id

  referenced_security_group_id = aws_security_group.archer_ssms.id
  ip_protocol                  = -1
}

resource "aws_vpc_security_group_ingress_rule" "to_ssms" {
  security_group_id = aws_security_group.archer_ssms.id

  referenced_security_group_id = aws_security_group.archer_sql_server.id
  ip_protocol                  = -1
}
