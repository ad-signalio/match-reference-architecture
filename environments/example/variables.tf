# Variables aws specific
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.25.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be a valid IPv4 CIDR block (e.g., 10.25.0.0/16)."
  }
}

variable "tags" {
  description = "Common AWS tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Variables specific to self hosted match environments
variable "env_id" {
  description = "The name of the environment, used to name terraformed resources"
  type        = string
  validation {
    condition     = length(var.env_id) >= 3 && length(var.env_id) <= 30 && can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.env_id))
    error_message = "env_id must start with a letter and be 3-30 characters long, containing only letters, numbers, and hyphens."
  }
}

variable "env_use" {
  description = "The use case for the environment (e.g., test, staging, prod)"
  type        = string
  validation {
    condition     = length(var.env_use) >= 3 && length(var.env_use) <= 20 && can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.env_use))
    error_message = "env_use must start with a letter and be 3-20 characters long, containing only letters, numbers, and hyphens."
  }
}

variable "env_region" {
  description = "The region identifier for the environment (e.g., us1, eu1)"
  type        = string
  validation {
    condition     = length(var.env_region) >= 2 && length(var.env_region) <= 10 && can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.env_region))
    error_message = "env_region must start with a letter and be 2-10 characters long, containing only letters, numbers, and hyphens."
  }
}

variable "env_additional_id" {
  description = "An additional identifier for the environment (e.g., sm, db)"
  type        = string
  default     = ""
  validation {
    condition     = length(var.env_additional_id) <= 10 && can(regex("^[a-zA-Z0-9-]*$", var.env_additional_id))
    error_message = "env_additional_id must be up to 10 characters long, containing only letters, numbers, and hyphens."
  }
}

variable "dockerconfig_json" {
  description = "Contents of the dockerconfig.json file"
  type        = string
  sensitive   = true
  default     = "e30K" # "{}" in base64
}

variable "availability_zone_name" {
  description = "For One Zone systems, specify the AWS Availability Zone in which to create the EKS cluster and EFS."
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "match"
}

variable "external_domain" {
  description = "External domain name for the application"
  type        = string
  default     = "example.sbox.as-priv.net"
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$", var.external_domain))
    error_message = "external_domain must be a valid domain name format."
  }
}

variable "eks_compute_nodes" {
  description = "Number of EKS worker nodes to create"
  type        = number
  default     = 2
  validation {
    condition     = var.eks_compute_nodes >= 1 && var.eks_compute_nodes <= 200
    error_message = "eks_compute_nodes must be between 1 and 200."
  }
}

variable "eks_compute_node_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.2xlarge"
  validation {
    condition     = can(regex("^[tmcr][0-9]+[a-z]*\\.[a-z0-9]+$", var.eks_compute_node_type))
    error_message = "eks_compute_node_type must be a valid EC2 instance type (e.g., t3.2xlarge, m5.large)."
  }
}

variable "rds_instance_class" {
  description = "RDS instance class for the PostgreSQL database"
  type        = string
  default     = "db.t3.small"
  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.rds_instance_class))
    error_message = "rds_instance_class must be a valid RDS instance class (e.g., db.t3.small, db.r5.large)."
  }
}

variable "storage_shared_storage_size" {
  description = "Size of the shared storage volume for EFS"
  type        = string
  default     = "100Gi"
  validation {
    condition     = can(regex("^[0-9]+[KMGT]i$", var.storage_shared_storage_size))
    error_message = "storage_shared_storage_size must be a valid Kubernetes storage size (e.g., 100Gi, 250Gi)."
  }
}

variable "admin_access_sso_permission_set_names" {
  description = "SSO Permission Set Names for admin access"
  type        = list(string)
  default     = []
}

variable "admin_access_role_names" {
  description = "Role Names for admin access"
  type        = list(string)
  default     = []
}

variable "install_helm_charts" {
  description = "value to determine whether to install helm charts for eks load balancer controller"
  type        = bool
  default     = true
}

variable "k8s_service_account_name_for_secrets" {
  description = "Kubernetes service account name for the application"
  type        = string
  default     = "secret-sync-sa"
}
