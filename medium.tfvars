# Sample defaults file for match-environment setup

# AWS Configuration
region                 = "us-east-1"
availability_zone_name = "us-east-1a"



# Basic Configuration
env_name               = "prod-example-md-us1" # Full project name, EKS clusters etc will be named after this
env_use                = "prod"
env_id                 = "example" # use your company name here
env_region             = "us1"
env_additional_id      = "md"
availability_zone_name = "us-east-1a"

# admin_access_sso_permission_set_names = [] add names of any SSO permission sets here, eg "infra", "developer"
# admin_access_role_names = [] add names of any IAM roles here, eg "Infra"


tags = {
  Environment = "prod"
  Company     = "example-company"
  ManagedBy   = "Terraform"
  #...
}

# Network and Domain Configuration
cidr            = "10.25.0.0/16"
external_domain = "my-company.sbox.as-priv.net"

# Customer/Company specific (you'll still be prompted for cust_id)
# cust_id = "my-company"


rds_instance_class          = "db.m5.4xlarge"
storage_shared_storage_size = "200Gi"
