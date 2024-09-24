resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  tags = merge(
    var.commom_tags,
    var.vpc_tags,
    {
      Name = local.resource
    }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.commom_tags,
    var.igw_tags,
    {
      Name = local.resource
    }
  )
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.az_names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.commom_tags,
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
    var.commom_tags,
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
    var.commom_tags,
    var.databse_subnet_tags,
    {
      Name = "${local.resource}-database-${local.az_names[count.index]}"
    }
  )
}

resource "aws_db_subnet_group" "default" {
  name       = local.resource
  subnet_ids = aws_subnet.database[*].id

  tags = merge(
    var.commom_tags,
    var.aws_db_subnet_group_tags,
    {
        Name = local.resource
    }
  )
}

resource "aws_eip" "lb" {
  domain = "vpc"
}

resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.commom_tags,
    var.aws_nat_gateway_tags,
    {
        Name = local.resource
    }
  )
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.main]
}

