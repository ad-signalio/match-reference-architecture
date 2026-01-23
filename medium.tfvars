# Sample defaults file for match-environment setup script
# Usage: ./setup.sh --defaults defaults.tfvars

# AWS Configuration
region                 = "us-east-1"
availability_zone_name = "us-east-1a"

# Basic Configuration
env_name = "medium-example-project"

tags = {
  Environment = "prod"
  Company     = "example-company"
  ManagedBy   = "Terraform"
  #...
}

# EKS Configuration
eks_compute_nodes     = 4
eks_compute_node_type = "c8i.xlarge"

# Network and Domain Configuration
cidr            = "10.25.0.0/16"
external_domain = "my-company.sbox.as-priv.net"

# Customer/Company specific (you'll still be prompted for cust_id)
# cust_id = "my-company"


rds_instance_class          = "db.m5.4xlarge"
storage_shared_storage_size = "200Gi"