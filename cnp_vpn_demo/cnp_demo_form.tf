#Set the region and use AWS
provider "aws" {
  profile = "default"
  version = "~> 2.8"
  region  = var.region
}

#Create the Inetnet facing VPC
resource "aws_vpc" "inet_vpc" {
  cidr_block = var.inet_vpc.cidr
  
  tags = {
    Name        = format("%s - %s", var.unique_id, var.inet_vpc.name)
    Description = format("%s - %s", var.unique_id, var.inet_vpc.desc)
  }
}

resource "aws_subnet" "inet_pub_sub" {
  vpc_id     = aws_vpc.inet_vpc.id 
  cidr_block = var.inet_vpc.pub_sub_cidr
  map_public_ip_on_launch = var.inet_vpc.auto_pub_ip

  tags = {
    Name = format("%s - %s", var.unique_id, var.inet_vpc.pub_sub_name)
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.inet_vpc.id
  depends_on = ["aws_subnet.inet_pub_sub"]
  lifecycle {
      create_before_destroy = true
    }
  tags = {
    Name = format("%s - %s - %s", var.unique_id, var.inet_vpc.name, "IGW")
  }
}

#Create an NGW just because
resource "aws_eip" "ngw_eip" {
  vpc      = true
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.ngw_eip.id
  subnet_id     = aws_subnet.inet_pub_sub.id
  depends_on = ["aws_internet_gateway.igw"]
  
  tags = {
    Name = format("%s - %s", var.unique_id, "NGW")
  }
}

resource "aws_subnet" "inet_conn_sub" {
  depends_on = ["aws_subnet.inet_pub_sub"]
  vpc_id      = aws_vpc.inet_vpc.id
  cidr_block  = var.inet_vpc.conn_sub_cidr
  availability_zone = aws_subnet.inet_pub_sub.availability_zone
  
  tags = {
    Name = format("%s - %s", var.unique_id, var.inet_vpc.conn_sub_name)
  }
}

#Create the Inspection VPC
resource "aws_vpc" "insp_vpc" {
  cidr_block = var.insp_vpc.cidr
  
  tags = {
    Name        = format("%s - %s", var.unique_id, var.insp_vpc.name)
    Description = format("%s - %s", var.unique_id, var.insp_vpc.desc)
  }
}

resource "aws_subnet" "insp_sub" {
  vpc_id      = aws_vpc.insp_vpc.id
  cidr_block  = var.insp_vpc.insp_sub_cidr
  
  tags = {
    Name = format("%s - %s", var.unique_id, var.insp_vpc.insp_sub_name)
  }
}

resource "aws_subnet" "insp_conn_sub" {
  depends_on = ["aws_subnet.insp_sub"]
  vpc_id      = aws_vpc.insp_vpc.id
  cidr_block  = var.insp_vpc.conn_sub_cidr
  availability_zone = aws_subnet.insp_sub.availability_zone
  
  tags = {
    Name = format("%s - %s", var.unique_id, var.insp_vpc.conn_sub_name)
  }
}

resource "aws_subnet" "insp_san_sub" {
  depends_on = ["aws_subnet.insp_sub"]
  vpc_id      = aws_vpc.insp_vpc.id
  cidr_block  = var.insp_vpc.san_sub_cidr
  availability_zone = aws_subnet.insp_sub.availability_zone
  
  tags = {
    Name = format("%s - %s", var.unique_id, var.insp_vpc.san_sub_name)
  }
}

#Create the Workload VPC
resource "aws_vpc" "work_vpc" {
  cidr_block = var.work_vpc.cidr
  
  tags = {
    Name        = format("%s - %s", var.unique_id, var.work_vpc.name)
    Description = format("%s - %s", var.unique_id, var.work_vpc.desc)
  }
}

resource "aws_subnet" "work_sub" {
  vpc_id      = aws_vpc.work_vpc.id
  cidr_block  = var.work_vpc.sub_cidr
  
  tags = {
    Name = format("%s - %s", var.unique_id, var.work_vpc.sub_name)
  }
}

######Transit GWs
#Inspection TGW
resource "aws_ec2_transit_gateway" "insp_tgw" {
  description = var.insp_tgw.desc
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  
  tags = {
    Name = format("%s - %s", var.unique_id, var.insp_tgw.name)
  }
}

resource "aws_ec2_transit_gateway_route_table" "insp_tgw_rtb" {
    transit_gateway_id = aws_ec2_transit_gateway.insp_tgw.id
    
    tags = {
      Name = format("%s - %s - %s", var.unique_id, var.insp_tgw.name, "RTB")
    }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "insp_tgw_inet_conn_att" {
  depends_on = ["aws_subnet.inet_conn_sub"]
  subnet_ids          = tolist([aws_subnet.inet_conn_sub.id])
  transit_gateway_id  = aws_ec2_transit_gateway.insp_tgw.id
  vpc_id              = aws_vpc.inet_vpc.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = format("%s - %s %s", var.unique_id, var.insp_tgw.name, var.insp_tgw.inet_conn_sub_att_name)
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "insp_tgw_work_att" {
  subnet_ids          = tolist([aws_subnet.work_sub.id])
  transit_gateway_id  = aws_ec2_transit_gateway.insp_tgw.id
  vpc_id              = aws_vpc.work_vpc.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = format("%s - %s %s", var.unique_id, var.insp_tgw.name, var.insp_tgw.work_sub_att_name)
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "insp_tgw_insp_conn_att" {
  depends_on = ["aws_subnet.insp_conn_sub"]
  subnet_ids          = tolist([aws_subnet.insp_conn_sub.id])
  transit_gateway_id  = aws_ec2_transit_gateway.insp_tgw.id
  vpc_id              = aws_vpc.insp_vpc.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = format("%s - %s %s", var.unique_id, var.insp_tgw.name, var.insp_tgw.insp_conn_sub_att_name)
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "insp_tgw_inet_conn_ass" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.insp_tgw_inet_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.insp_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route_table_association" "insp_tgw_work_ass" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.insp_tgw_work_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.insp_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route" "insp_tgw_route_default" {
  destination_cidr_block            = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.insp_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.insp_tgw_rtb.id
}

/*
resource "aws_ec2_transit_gateway_route" "insp_tgw_route_work_vpc" {
  destination_cidr_block            = var.work_vpc.cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.insp_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.insp_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route" "insp_tgw_route_insp_vpc" {
  destination_cidr_block            = var.insp_vpc.cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.insp_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.insp_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route" "insp_tgw_route_inet_vpc" {
  destination_cidr_block            = var.inet_vpc.cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.insp_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.insp_tgw_rtb.id
}*/


#Sanitized TGW
resource "aws_ec2_transit_gateway" "san_tgw" {
  description = var.san_tgw.desc
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  
  tags = {
    Name = format("%s - %s", var.unique_id, var.san_tgw.name)
  }
}

resource "aws_ec2_transit_gateway_route_table" "san_tgw_rtb" {
    transit_gateway_id = aws_ec2_transit_gateway.san_tgw.id
    
    tags = {
      Name = format("%s - %s - %s", var.unique_id, var.san_tgw.name, "RTB")
    }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "san_tgw_insp_conn_att" {
  depends_on = ["aws_ec2_transit_gateway.san_tgw", "aws_ec2_transit_gateway_route_table.san_tgw_rtb", "aws_subnet.insp_conn_sub"]
  subnet_ids          = tolist([aws_subnet.insp_conn_sub.id])
  transit_gateway_id  = aws_ec2_transit_gateway.san_tgw.id
  vpc_id              = aws_vpc.insp_vpc.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = format("%s - %s %s", var.unique_id, var.san_tgw.name, var.san_tgw.insp_conn_sub_att_name)
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "san_tgw_inet_conn_att" {
  depends_on = ["aws_ec2_transit_gateway.san_tgw", "aws_ec2_transit_gateway_route_table.san_tgw_rtb", "aws_subnet.inet_conn_sub"]
  subnet_ids          = tolist([aws_subnet.inet_conn_sub.id])
  transit_gateway_id  = aws_ec2_transit_gateway.san_tgw.id
  vpc_id              = aws_vpc.inet_vpc.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = format("%s - %s %s", var.unique_id, var.san_tgw.name, var.san_tgw.inet_conn_sub_att_name)
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "san_tgw_work_att" {
  depends_on = ["aws_ec2_transit_gateway.san_tgw", "aws_ec2_transit_gateway_route_table.san_tgw_rtb"]
  subnet_ids          = tolist([aws_subnet.work_sub.id])
  transit_gateway_id  = aws_ec2_transit_gateway.san_tgw.id
  vpc_id              = aws_vpc.work_vpc.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = format("%s - %s %s", var.unique_id, var.san_tgw.name, var.san_tgw.work_sub_att_name)
  }
}

resource "aws_ec2_transit_gateway_route_table_propagation" "san_tgw_inet_conn_prop" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.san_tgw_inet_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.san_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "san_tgw_work_prop" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.san_tgw_work_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.san_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "san_tgw_insp_conn_prop" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.san_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.san_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route_table_association" "san_tgw_insp_conn_ass" {
  depends_on = ["aws_ec2_transit_gateway_vpc_attachment.san_tgw_insp_conn_att"]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.san_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.san_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route" "san_tgw_route_default" {
  destination_cidr_block            = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.san_tgw_inet_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.san_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route" "san_tgw_route_training_lab_vpn" {
  depends_on = ["data.aws_ec2_transit_gateway_vpn_attachment.vpn_tgw_training_lab_vpn_att"]
  destination_cidr_block            = "172.16.5.0/24"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.san_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.san_tgw_rtb.id
}
#######VPN TGW##############

resource "aws_ec2_transit_gateway" "vpn_tgw" {
  description = var.vpn_tgw.desc
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  
  tags = {
    Name = format("%s - %s", var.unique_id, var.vpn_tgw.name)
  }
}

resource "aws_ec2_transit_gateway_route_table" "vpn_tgw_rtb" {
    transit_gateway_id = aws_ec2_transit_gateway.vpn_tgw.id
    
    tags = {
      Name = format("%s - %s - %s", var.unique_id, var.vpn_tgw.name, "RTB")
    }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpn_tgw_insp_conn_att" {
  subnet_ids          = tolist([aws_subnet.insp_conn_sub.id])
  transit_gateway_id  = aws_ec2_transit_gateway.vpn_tgw.id
  vpc_id              = aws_vpc.insp_vpc.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = format("%s - %s %s", var.unique_id, var.vpn_tgw.name, var.vpn_tgw.insp_conn_sub_att_name)
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "vpn_tgw_insp_conn_ass" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpn_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn_tgw_rtb.id
}

/*
resource "aws_ec2_transit_gateway_vpc_attachment" "vpn_tgw_inet_conn_att" {
  subnet_ids          = tolist([aws_subnet.inet_conn_sub.id])
  transit_gateway_id  = aws_ec2_transit_gateway.vpn_tgw.id
  vpc_id              = aws_vpc.inet_vpc.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = format("%s - %s %s", var.unique_id, var.vpn_tgw.name, var.vpn_tgw.inet_conn_sub_att_name)
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "vpn_tgw_inet_conn_ass" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpn_tgw_inet_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpn_tgw_work_att" {
  subnet_ids          = tolist([aws_subnet.work_sub.id])
  transit_gateway_id  = aws_ec2_transit_gateway.vpn_tgw.id
  vpc_id              = aws_vpc.work_vpc.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = format("%s - %s %s", var.unique_id, var.vpn_tgw.name, var.vpn_tgw.work_sub_att_name)
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "vpn_tgw_work_ass" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpn_tgw_work_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn_tgw_rtb.id
}*/


resource "aws_ec2_transit_gateway_route" "vpn_tgw_route_default" {
  destination_cidr_block            = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpn_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn_tgw_rtb.id
}

/*
resource "aws_ec2_transit_gateway_route" "vpn_tgw_route_work_vpc" {
  destination_cidr_block            = var.work_vpc.cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpn_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route" "vpn_tgw_route_insp_vpc" {
  destination_cidr_block            = var.insp_vpc.cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpn_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route" "vpn_tgw_route_inet_vpc" {
  destination_cidr_block            = var.inet_vpc.cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpn_tgw_insp_conn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn_tgw_rtb.id
}*/


resource "aws_customer_gateway" "customer_gw" {
  bgp_asn    = 65000
  ip_address = var.customer_gw_ip
  type       = "ipsec.1"
  
  tags = {
    Name = "BHDEMO - Training Lab Customer GW"
  }
}

resource "aws_vpn_connection" "training_lab_vpn" {
  customer_gateway_id = aws_customer_gateway.customer_gw.id
  transit_gateway_id  = aws_ec2_transit_gateway.vpn_tgw.id
  type                = aws_customer_gateway.customer_gw.type
  static_routes_only = true
  
  tags = {
    Name = "BHDEMO - Training Lab VPN Connection"
  }
}

data "aws_ec2_transit_gateway_vpn_attachment" "vpn_tgw_training_lab_vpn_att" {
  transit_gateway_id = aws_ec2_transit_gateway.vpn_tgw.id
  vpn_connection_id = aws_vpn_connection.training_lab_vpn.id
  
  tags = {
    Name = "BHDEMO - Training Lab VPN ATT"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "vpn_tgw_training_lab_vpn_rtb_ass" {
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpn_attachment.vpn_tgw_training_lab_vpn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn_tgw_rtb.id
}

resource "aws_ec2_transit_gateway_route" "vpn_tgw_route_training_lab" {
  destination_cidr_block         = "172.16.5.0/24"
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpn_attachment.vpn_tgw_training_lab_vpn_att.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpn_tgw_rtb.id
}

################################################
####################Subnet Route Tables#########
resource "aws_route_table" "insp_rtb" {
  vpc_id = aws_vpc.insp_vpc.id
  
  tags = {
    Name = format("%s - %s - %s", var.unique_id, var.insp_vpc.insp_sub_name, "RTB")
  }
}

resource "aws_route_table_association" "insp_rtb_ass" {
  subnet_id      = aws_subnet.insp_sub.id
  route_table_id = aws_route_table.insp_rtb.id
}

resource "aws_route_table" "insp_conn_rtb_bypass" {
  vpc_id = aws_vpc.insp_vpc.id
  depends_on = ["aws_ec2_transit_gateway.san_tgw"]

  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.san_tgw.id
  }
  
  route {
    cidr_block = "172.16.5.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.vpn_tgw.id
  }

  tags = {
    Name = format("%s - %s - %s", var.unique_id, var.insp_vpc.conn_sub_name, "Bypass RTB")
  }
}

resource "aws_route_table" "insp_conn_rtb_inspect" {
  vpc_id = aws_vpc.insp_vpc.id
  depends_on = ["aws_network_interface.cnp_1a"]

  route {
    cidr_block = "0.0.0.0/0"
    network_interface_id = aws_network_interface.cnp_1a.id
  }

  tags = {
    Name = format("%s - %s - %s", var.unique_id, var.insp_vpc.conn_sub_name, "Inspecting RTB")
  }
}

#associate the Inspection Connection Bypass Route table with the Inspection Connection Subnet
#This allows you to setup everything while the CNP is bypassed.  You can cut the CNP inline later
#by associating the Inspection Connection Inspecting RTB with Inspection Connection Subnet
resource "aws_route_table_association" "insp_conn_rtb_bypass_ass" {
  subnet_id      = aws_subnet.insp_conn_sub.id
  route_table_id = aws_route_table.insp_conn_rtb_bypass.id
}

resource "aws_main_route_table_association" "insp_conn_rtb_bypass_main" {
  vpc_id          = aws_vpc.insp_vpc.id
  route_table_id  = aws_route_table.insp_conn_rtb_bypass.id
}

resource "aws_route_table" "insp_san_rtb" {
  vpc_id = aws_vpc.insp_vpc.id
  depends_on = ["aws_ec2_transit_gateway.san_tgw"]

  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.san_tgw.id
  }
  
  route {
    cidr_block = "172.16.5.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.vpn_tgw.id
  }

  tags = {
    Name = format("%s - %s - %s", var.unique_id, var.insp_vpc.san_sub_name, "RTB")
  }
}

resource "aws_route_table_association" "insp_san_rtb_ass" {
  subnet_id      = aws_subnet.insp_san_sub.id
  route_table_id = aws_route_table.insp_san_rtb.id
}

resource "aws_route_table" "pub_sub_rtb" {
  vpc_id = aws_vpc.inet_vpc.id
  
  lifecycle {
      create_before_destroy = true
    }
    
  route {
    cidr_block = var.work_vpc.cidr
    transit_gateway_id = aws_ec2_transit_gateway.insp_tgw.id
  }

  route {
    cidr_block = var.insp_vpc.cidr
    transit_gateway_id = aws_ec2_transit_gateway.insp_tgw.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  route {
    cidr_block = "172.16.5.0/24"
    transit_gateway_id = aws_ec2_transit_gateway.insp_tgw.id
  }

  tags = {
    Name = format("%s - %s - %s", var.unique_id, var.inet_vpc.pub_sub_name, "RTB")
  }
}

resource "aws_route_table_association" "pub_sub_rtb_ass" {
  subnet_id      = aws_subnet.inet_pub_sub.id
  route_table_id = aws_route_table.pub_sub_rtb.id
}

resource "aws_route_table" "pub_conn_rtb" {
  vpc_id = aws_vpc.inet_vpc.id
  depends_on = ["aws_nat_gateway.ngw"]
  
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
  
/*
  route {
    cidr_block = var.insp_vpc.cidr
    transit_gateway_id = aws_ec2_transit_gateway.insp_tgw.id
  }
  
  route {
    cidr_block = var.work_vpc.cidr
    transit_gateway_id = aws_ec2_transit_gateway.insp_tgw.id
  }*/


  tags = {
    Name = format("%s - %s - %s", var.unique_id, var.inet_vpc.conn_sub_name, "RTB")
  }
}

resource "aws_route_table_association" "pub_conn_rtb_ass" {
  subnet_id      = aws_subnet.inet_conn_sub.id
  route_table_id = aws_route_table.pub_conn_rtb.id
}

resource "aws_main_route_table_association" "pub_conn_rtb_main" {
  depends_on = ["aws_route_table_association.pub_conn_rtb_ass"]
  vpc_id          = aws_vpc.inet_vpc.id
  route_table_id  = aws_route_table.pub_conn_rtb.id
}

resource "aws_route_table" "work_sub_rtb" {
  vpc_id = aws_vpc.work_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.insp_tgw.id
  }

  tags = {
    Name = format("%s - %s - %s", var.unique_id, var.work_vpc.sub_name, "RTB")
  }
}

resource "aws_route_table_association" "work_rtb_ass" {
  subnet_id      = aws_subnet.work_sub.id
  route_table_id = aws_route_table.work_sub_rtb.id
}

#Create Security Groups
resource "aws_security_group" "work_vpc_sg" {
  vpc_id = aws_vpc.work_vpc.id
  name         = format("%s - %s - %s", var.unique_id, var.work_vpc.name, "SG")
  description  = format("%s - %s - %s", var.unique_id, var.work_vpc.name, "SG")
  
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [var.inet_vpc.cidr, var.insp_vpc.cidr, var.work_vpc.cidr, "172.16.5.0/24"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "insp_conn_sg" {
  vpc_id = aws_vpc.insp_vpc.id
  name         = format("%s - %s - %s", var.unique_id, var.insp_vpc.name, "Management - SG")
  description  = format("%s - %s - %s", var.unique_id, var.insp_vpc.name, "Management - SG")
  
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [var.inet_vpc.cidr, var.insp_vpc.cidr, var.work_vpc.cidr, "172.16.5.0/24"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "insp_traffic_sg" {
  vpc_id = aws_vpc.insp_vpc.id
  name         = format("%s - %s - %s", var.unique_id, var.insp_vpc.name, "Inspected Traffic - SG")
  description  = format("%s - %s - %s", var.unique_id, var.insp_vpc.name, "Inspected Traffic - SG")
  
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "inet_pub_vpc_sg" {
  vpc_id = aws_vpc.inet_vpc.id
  name         = format("%s - %s - %s", var.unique_id, var.inet_vpc.name, "Public Subnet - SG")
  description  = format("%s - %s - %s", var.unique_id, var.inet_vpc.name, "SG")
  
  #allow SSH connections from any IP.  Your bastion instance should be the instance host with a 
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [var.inet_vpc.cidr, var.insp_vpc.cidr, var.work_vpc.cidr, "172.16.5.0/24"]
  }
  
  #allow any traffic to egress to the Internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu_server_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "bastion_host" {
  ami           = data.aws_ami.ubuntu_server_ami.id
  instance_type = var.types.bastion
  key_name = var.key_pair
  vpc_security_group_ids = [aws_security_group.inet_pub_vpc_sg.id]
  subnet_id = aws_subnet.inet_pub_sub.id
  source_dest_check = false
  tags = {
    Name = format("%s - %s", var.unique_id, "Bastion instance")
    Description = "Bastion instance"
  }
}

resource "aws_instance" "work_host" {
  ami           = data.aws_ami.ubuntu_server_ami.id
  instance_type = var.types.work
  key_name = var.key_pair
  vpc_security_group_ids = [aws_security_group.work_vpc_sg.id]
  subnet_id = aws_subnet.work_sub.id
  tags = {
    Name = format("%s - %s", var.unique_id, "Workload instance")
    Description = "Workload instance"
  }
}

#CNP Instance
/*
resource "aws_iam_policy" "cnp_logs_policy" {
  # ... other configuration ...

  policy = "${file("cloudwatch_logs_policy.json")}"
}

resource "aws_iam_role" "cnp_logs_role" {
  name               = "CNP Cloudwatch logs Role"
  assume_role_policy = "${file("cloudwatch_logs_policy.json")}"
  tags = var.cloudwatch_logs_role.tags
}*/

resource "aws_network_interface" "cnp_mgmt" {
  subnet_id = aws_subnet.insp_conn_sub.id
  security_groups = [aws_security_group.insp_conn_sg.id]
  
  tags = {
    Name = "CNP Mangement Interface"
    Description = "Cloud Network Protection Management Interface"
  }
}

resource "aws_network_interface" "cnp_1a" {
  subnet_id = aws_subnet.insp_sub.id
  security_groups = [aws_security_group.insp_traffic_sg.id]
  source_dest_check = false
  
  tags = {
    Name = "CNP Interface 1A"
    Description = "Cloud Network Protection Inspection Interface 1A"
  }
}

resource "aws_network_interface" "cnp_1b" {
  subnet_id = aws_subnet.insp_san_sub.id
  security_groups = [aws_security_group.insp_traffic_sg.id]
  source_dest_check = false
  
  tags = {
    Name = "CNP Interface 1B"
    Description = "Cloud Network Protection Sanitized Interface 1B"
  }
}

#UNQUOTE WHEN READY FOR FINAL INSTALL
#Identify Ubuntu 18.04 Server the AMI based on the region
data "aws_ami" "cnp_ami" {
  most_recent = true
  
  filter {
    name = "name"
    values = [var.cnp_amis.name]
  }
  
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  
  owners = ["679593333241"] #aws-marketplace
}

resource "aws_instance" "cnp_1" {
  ami           = data.aws_ami.cnp_ami.id
  instance_type = var.types.cnp
  key_name = var.key_pair
  #iam_instance_profile = 
  
  network_interface {
    network_interface_id = aws_network_interface.cnp_mgmt.id
    device_index = 0
  }
  
  network_interface {
    network_interface_id = aws_network_interface.cnp_1a.id
    device_index = 1
  }
  
  network_interface {
    network_interface_id = aws_network_interface.cnp_1b.id
    device_index = 2
  }
  
  tags = {
    Name = format("%s - %s", var.unique_id, "CNP Instance")
    Description = "Cloud Network Protection Instance"
  }
}

output "bastion_public_ip" {
  value = aws_instance.bastion_host.public_ip
}

output "bastion_private_ip" {
  value = aws_instance.bastion_host.private_ip
}

output "workload_ip" {
  value = aws_instance.work_host.private_ip
}

output "cnp_mgmt_ip" {
  value = aws_network_interface.cnp_mgmt.private_ips
}

output "cnp_1A_ip" {
  value = aws_network_interface.cnp_1a.private_ips
}

output "cnp_1B_ip" {
  value = aws_network_interface.cnp_1b.private_ips
}