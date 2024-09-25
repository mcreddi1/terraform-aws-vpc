#Creating AWS VPC
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  tags = merge(
    var.common_tags,
    var.vpc_tags,
    {
      Name = local.resource
    }
  )
}

#creating internet gateway to associate with VPC
#Internet GW allows both inbound and outbound access to the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.igw_tags,
    {
      Name = local.resource
    }
  )
}

#Creating subnets for public, private and database subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.az_names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    var.public_subnet_tags,
    {
      Name = "${local.resource}-public-${local.az_names[count.index]}"
    }
  )
}


resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]

  tags = merge(
    var.common_tags,
    var.private_subnet_tags,
    {
      Name = "${local.resource}-private-${local.az_names[count.index]}"
    }
  )
}

resource "aws_subnet" "database" {
  count             = length(var.database_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]

  tags = merge(
    var.common_tags,
    var.databse_subnet_tags,
    {
      Name = "${local.resource}-database-${local.az_names[count.index]}"
    }
  )
}

#Creating aws db subnet group for grouping bd subnets
resource "aws_db_subnet_group" "default" {
  name       = local.resource
  subnet_ids = aws_subnet.database[*].id

  tags = merge(
    var.common_tags,
    var.aws_db_subnet_group_tags,
    {
      Name = local.resource
    }
  )
}

#creating elastic IP 
#mask the failure of an instance or software by rapidly remapping the address to another instance in your account
resource "aws_eip" "lb" {
  domain = "vpc"
}

#NAT Gateway only allows outbound access.
#a service that allows instances in a private subnet to access the internet while preventing external services from connecting to them
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.common_tags,
    var.aws_nat_gateway_tags,
    {
      Name = local.resource
    }
  )
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.main]
}

#public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.public_route_table_tags,
    {
      Name = "${local.resource}-public" #expense-dev-public
    }
  )
}

#databse route table
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.database_route_table_tags,
    {
      Name = "${local.resource}-database" #expense-dev-database
    }
  )
}

#private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.private_route_table_tags,
    {
      Name = "${local.resource}-private" #expense-dev-private
    }
  )
}

#Routes
#a set of rules, known as routes, that determines where network traffic is directed
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "private-nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

#Route Tables
#creates an association between a route table and a subnet, internet gateway, or virtual private gateway
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)
  route_table_id = aws_route_table.public.id
  subnet_id = aws_subnet.public[count.index].id
}


resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)
  route_table_id = aws_route_table.public.id
  subnet_id = aws_subnet.private[count.index].id
}

resource "aws_route_table_association" "database" {
  count = length(var.database_subnet_cidrs)
  route_table_id = aws_route_table.database.id
  subnet_id = aws_subnet.database[count.index].id
}