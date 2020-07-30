data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # The marketplace product code for all versions of Panorama
  //product_code = "eclz7j04vu9lf8ont8ta3n17o"
  availability_zones = data.aws_availability_zones.available.names
  sg_rules = {
    ssh-from-on-prem = {
      type        = "ingress"
      cidr_blocks = var.mgmt_subnet
      protocol    = "tcp"
      from_port   = "22"
      to_port     = "22"
    }
    https-from-on-prem = {
      type        = "ingress"
      cidr_blocks = var.mgmt_subnet
      protocol    = "tcp"
      from_port   = "443"
      to_port     = "443"
    }
    ingress = {
      type        = "ingress"
      cidr_blocks = var.cidr_block
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
    }
    egress = {
      type        = "egress"
      cidr_blocks = "0.0.0.0/0"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
    }
  }
}

/* Find the image for Panorama
data "aws_ami" "panorama" {
  most_recent = true
  owners = ["aws-marketplace"]
  filter {
    name   = "owner-alias"
    values = ["aws-marketplace"]
  }

  filter {
    name   = "product-code"
    values = [local.product_code]
  }

  filter {
    name   = "name"
    # Using the asterisc, this finds the latest release in the mainline version
    values = ["Panorama-AWS-${var.panorama_version}*"]
  }
}*/

data "aws_ami" "ubuntu-linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}


# Create a VPC for Panorama
resource "aws_vpc" "default" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    {
      Name        = "${var.name} VPC",
      Environment = var.environment
    }
  )
}

# Create a subnet for the primary Panorama 
resource "aws_subnet" "primary" {
  vpc_id            = aws_vpc.default.id
  availability_zone = local.availability_zones[0]

  cidr_block = cidrsubnet(aws_vpc.default.cidr_block, 1, 0)

  tags = {
    Name = "${var.name} - ${local.availability_zones[0]}"
  }
}

# Create an IGW so Panorama can get to the Internet for updates and licensing
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.default.id

  tags = merge(
    {
      Name        = "${var.name} IntenetGW",
      Environment = var.environment
    }
  )
}

# Create a new route table that will have a default route to the IGW
resource "aws_route_table" "igw_rt" {
  vpc_id = aws_vpc.default.id

  tags = merge(
    {
      Name        = "${var.name} RouteTable",
      Environment = var.environment
    }
  )
}

# Set the default route to point to the IGW
resource "aws_route" "default_rt" {
  route_table_id         = aws_route_table.igw_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Set the primary Panorama subnet to use the IGW route table
resource "aws_route_table_association" "igw_primary" {
  subnet_id      = aws_subnet.primary.id
  route_table_id = aws_route_table.igw_rt.id
}

# Create an interface and set the internal IP to the 4th IP address in the subnet.
resource "aws_network_interface" "primary" {
  subnet_id         = aws_subnet.primary.id
  private_ips       = [cidrhost(aws_subnet.primary.cidr_block, 4)]
  security_groups   = [aws_security_group.management.id]
  source_dest_check = true

  tags = merge(
    {
      Name        = "${var.name} PrimaryInterface",
      Environment = var.environment
    }
  )
}

# Create an external IP address and associate it to the management interface
resource "aws_eip" "primary" {
  vpc               = true
  network_interface = aws_network_interface.primary.id

  tags = merge(
    {
      Name        = "${var.name} Primary EIP",
      Environment = var.environment
    }
  )

  depends_on = [
    aws_instance.primary,
  ]
}

# Create a security group

resource "aws_security_group" "management" {
  name        = "${var.name} Panorama SG"
  description = "Inbound filtering for Panorama"
  vpc_id      = aws_vpc.default.id
}

resource "aws_security_group_rule" "sg-out-mgmt-rules" {
  for_each          = local.sg_rules
  security_group_id = aws_security_group.management.id
  type              = each.value.type
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = [each.value.cidr_blocks]
}

# Create the panorama instance

resource "aws_instance" "primary" {
  disable_api_termination              = false
  instance_initiated_shutdown_behavior = "stop"

  ebs_optimized = true
  ami           = data.aws_ami.ubuntu-linux.image_id
  instance_type = var.instance_type
  key_name      = var.key_name

  monitoring = false

  root_block_device {
    delete_on_termination = "true"
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.primary.id
  }

  tags = merge(
    {
      Name        = "${var.name} Primary Instance",
      Environment = var.environment
    }
  )
}


# Everything below here is for the second Panorama. Since it is optional the resources use the enable_ha variable
# to determine if they should deploy.

# The subnet assumes that there are at least two availablity zones. 
resource "aws_subnet" "secondary" {
  count             = var.enable_ha ? 1 : 0
  vpc_id            = aws_vpc.default.id
  availability_zone = local.availability_zones[1]

  cidr_block = cidrsubnet(aws_vpc.default.cidr_block, 1, 1)

  tags = {
    Name = "${var.name} - ${local.availability_zones[1]}"
  }
}

resource "aws_route_table_association" "igw_secondary" {
  count          = var.enable_ha ? 1 : 0
  subnet_id      = aws_subnet.secondary[0].id
  route_table_id = aws_route_table.igw_rt.id
}

resource "aws_network_interface" "secondary" {
  count     = var.enable_ha ? 1 : 0
  subnet_id = aws_subnet.secondary[0].id

  private_ips       = [cidrhost(aws_subnet.secondary[0].cidr_block, 4)]
  security_groups   = [aws_security_group.management.id]
  source_dest_check = true

  tags = merge(
    {
      Name        = "${var.name} SecondaryInterface",
      Environment = var.environment
    }
  )
}

resource "aws_eip" "secondary" {
  count             = var.enable_ha ? 1 : 0
  vpc               = true
  network_interface = aws_network_interface.secondary[0].id

  tags = {
    Name = "${var.name} Secondary EIP"
  }

  depends_on = [
    aws_instance.secondary,
  ]
}

resource "aws_instance" "secondary" {
  count                                = var.enable_ha ? 1 : 0
  disable_api_termination              = false
  instance_initiated_shutdown_behavior = "stop"

  ebs_optimized = true
  ami           = data.aws_ami.ubuntu-linux.image_id
  instance_type = var.instance_type
  key_name      = var.key_name

  monitoring = false

  # Setting this to true so that the disk is deleted when the instance is deleted. 
  root_block_device {
    delete_on_termination = "true"
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.secondary[0].id
  }

  tags = merge(
    {
      Name        = "${var.name} Secondary Instance",
      Environment = var.environment
    }
  )
}

