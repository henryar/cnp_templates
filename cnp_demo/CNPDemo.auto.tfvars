/*!!!!!!!!!!!!!!ATTENTION:!!!!!!!!!!!!!!!!!!
Export these environment variables prior to applying this Terraform plan
$ export AWS_ACCESS_KEY_ID="anaccesskey"
$ export AWS_SECRET_ACCESS_KEY="asecretkey"
*/

#Set a unique identifier which will be added to any tags
unique_id = "AWGCNPDEMO"
#All Ubuntu Server AMIs per region
region = "us-east-2"
#The name of the keypair you will use to connect to the instances.  This keypair must exist in the region
key_pair = "cnp_demo_keys"
#Provide the full path to your private key file that corresponds to the keypair you specified above.
private_key_file = "/Users/adamg/src/terraform/cnp_demo/cnp_demo_keys.pem"
#
#-------DO NOT CHANGE ANY MORE UNLESS YOU KNOW WHAT YOU ARE DOING------
sms_api_key = "50AF8165-62FB-4D02-BBBC-EB98A343C8CF"

sms_private_ip = "10.0.0.20"

sms_ami_id = "ami-084ffcf0cecf53d7b"

#All CNP AMIs per region
cnp_amis = {
  owner_id = "679593333241" #AWS Marketplace
  name = "IPS_AMI--5.1.1.24037*"
}

#Instance types
types = {
  bastion = "t2.micro"
  work = "t2.micro"
  cnp = "c5.2xlarge"
  sms = "t2.large"
}

#Internet VPC specific values
inet_vpc = {
  cidr = "10.0.0.0/16"
  name = "inet_vpc"
  desc = "Internet VPC"
  pub_sub_cidr = "10.0.0.0/24"
  pub_sub_name = "Internet VPC - Public Subnet"
  conn_sub_cidr = "10.0.1.0/24"
  conn_sub_name = "Internet VPC - Connection Subnet"
  auto_pub_ip = true
  sms_private_ip = "10.0.0.20"
}

#Inspection VPC specific values
insp_vpc = {
  cidr = "172.20.0.0/16"
  name = "insp_vpc"
  desc = "Inspection VPC"
  insp_sub_cidr = "172.20.1.0/24"
  insp_sub_name = "Inspection VPC - Inspection Subnet"
  conn_sub_cidr = "172.20.0.0/24"
  conn_sub_name = "Inspection VPC - Connection Subnet"
  san_sub_cidr = "172.20.2.0/24"
  san_sub_name = "Inspection VPC - Sanitized Subnet"
}

#Workload VPC specific values
work_vpc = {
  cidr = "192.168.152.0/24"
  name = "work_vpc"
  desc = "Workload VPC"
  sub_cidr = "192.168.152.0/24"
  sub_name = "Workload VPC Subnet"
  sg_name = "Default SG"
}

#Inspection TGW
insp_tgw = {
  desc = "Inspection TGW"
  name = "Inspection TGW"
  insp_conn_sub_att_name = "Inspection Connection Subnet ATT"
  inet_conn_sub_att_name = "Internet Connection Subnet ATT"
  work_sub_att_name = "Workload Subnet ATT"
}

#Sanitized TGW
san_tgw = {
  desc = "Sanitized TGW"
  name = "Sanitized TGW"
  inet_conn_sub_att_name = "Internet Connection Subnet ATT"
  insp_conn_sub_att_name = "Inspection Connection Subnet ATT"
  work_sub_att_name = "Workload Subnet ATT"
}

#Premise TGW - connected on premise resources to cloud resource
vpn_tgw = {
  desc = "VPN TGW"
  name = "VPN TGW"
  inet_conn_sub_att_name = "Internet Connection Subnet ATT"
  insp_conn_sub_att_name = "Inspection Connection Subnet ATT"
  work_sub_att_name = "Workload Subnet ATT"
  #vpn_tgw_prem_att = "Premise VPN ATT"
}

