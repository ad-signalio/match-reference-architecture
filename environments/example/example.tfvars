env_name               = "example" # use your company name here
availability_zone_name = "us-east-1a"
# EKS Configuration
eks_compute_nodes     = 2
eks_compute_node_type = "t3.2xlarge"

# RDS Configuration
rds_instance_class = "db.t3.small"

# Storage Configuration
storage_shared_storage_size = "100Gi"

# Network and Domain Configuration
cidr             = "10.28.0.0/16"
external_domain  = "example.yourdomain.com"
environment_size = "small"