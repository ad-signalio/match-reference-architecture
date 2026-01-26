# Match Environment Reference Architecture

## Overview

A Terraform-based reference architecture for deploying match environments on AWS EKS.

> **Important Note**: This reference architecture is intended as a **guide and starting point**. You may adapt it to work with your existing infrastructure, including existing EKS clusters, VPCs, or other AWS resources. The architecture is modular and can be customized to integrate with your current setup rather than creating everything from scratch.

The resultant environment will be suitable for installing the `helm-match` chart to provision the Match environment.

## Architecture Overview

This reference architecture deploys a complete AWS infrastructure stack including:

- **Amazon EKS Cluster** - Managed Kubernetes service with auto-scaling node groups
- **VPC & Networking** - Secure network foundation with public/private subnets
- **RDS Databases** - Managed relational database services
- **S3 Storage** - Object storage with encryption and versioning
- **IAM Roles & Policies** - Least-privilege access controls
- **Load Balancer Controller** - AWS Application Load Balancer integration
- **EFS** - EFS Volumes for use as shared storage on the EKS cluster
- **Monitoring & Logging** - CloudWatch integration and observability stack

## Prerequisites

Before using this reference architecture, ensure you have:

- **AWS CLI** (v2.0+) configured with appropriate permissions
- **Terraform** (v1.13+) installed
- **kubectl** for Kubernetes cluster management
- **Helm** (v3.0+) for package management
- **Git** for version control

### Provider Version Requirements

This reference architecture requires the following provider versions (as defined in `environments/test-company/provider.tf`):

| Provider | Minimum Version | Purpose |
|----------|----------------|---------|
| **Terraform** | `>= 1.13` | Infrastructure as Code platform |
| **AWS** | `>= 5.70` | AWS resource management and EKS/VPC/RDS operations |
| **Kubernetes** | `>= 2.20` | EKS cluster management and resource provisioning |
| **Helm** | `>= 2.9` | Kubernetes package management (Load Balancer Controller) |
| **Random** | `>= 3.1` | Secure random value generation for resources |

These versions ensure compatibility with all infrastructure modules and provide access to the latest AWS EKS features and security improvements.

### Required AWS Permissions

Your AWS credentials must have permissions for:
- EKS cluster creation and management
- VPC and networking resources
- IAM role and policy management (including iam:PassRole)
- S3 bucket operations
- RDS instance management
- CloudWatch and logging services

Sample wide-permission IAM policy (for testing only — use least-privilege in production):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "WideServicePermissions",
            "Effect": "Allow",
            "Action": [
                "eks:*",
                "ec2:*",
                "iam:*",
                "s3:*",
                "rds:*",
                "logs:*",
                "cloudwatch:*",
                "elasticloadbalancing:*",
                "autoscaling:*",
                "route53:*",
                "secretsmanager:*",
                "kms:*",
                "ssm:*",
                "sts:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### ⚠️ WARNING — Highly permissive policy

**This policy is highly permissive.** Grant only the minimum required permissions for production environments and prefer scoped policies and role separation.

Recommended actions:
- Use least-privilege IAM policies tailored to each service
- Split responsibilities into separate roles (e.g., admin, deploy, runtime)
- Apply permission boundaries, SCPs, or session policies where possible
- Regularly audit IAM activity and rotate credentials
- Restrict use of wide wildcard actions and avoid Resource="*" in production
- Use a restrictive policy for production and a broader one only for short-lived testing

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd match-reference-architecture
   ```

2. **Create environment directory**
   ```bash
   cp -r environments/example environments/your-company-name
   cd environments/your-company-name
   ```

3. **Configure variables**
   ```bash
   # Edit the  an example .tfvars file with your specific values
   cp <size>.tfvars your-comanay-name.tfvars
   vim your-company-name.tfvars
   # Edit the backend.tf to use your state bucket and statefile
   vim backend.tf
   # Edit the main.tf to edit the local variable block
    vim main.tf

   ```

4. **Initialize and deploy**
   ```bash
   terraform init
   terraform plan -var-file="your-company-name.tfvars"
   terraform apply -var-file="your-company-name.tfvars"
   ```

## Deployment Sizing Options

This reference architecture includes pre-configured sizing templates there are corresponding small.yaml, medium.yaml and large.yaml values in the Match Helm Chart that match these capacities. Work with Ad Signal Technical Services to understand your individual system needs. These configurations are static with the ability to autoscale and are optimized for continuous throughput.

### Small Deployment

- **Compute**: 1 node c8i.4xlarge (16 vCPU, 32 GB RAM)
- **Database**: db.m5.4xlarge (16 vCPU, 64 GB RAM)
- **Throughput**: 1 Hour of content will take approximately 1 hour to process

### Medium Deployment

- **Compute**: 4 nodes × c8i.4xlarge (16v CPU, 32 GB RAM each)
- **Database**: db.m5.4xlarge (16 vCPU, 64 GB RAM)
- **Throughput**: 2.5 Hours of content will take approximately 1 hour to process

### Large Deployment

- **Compute**: 12 nodes × m8i.4xlarge (16 vCPU, 32 GB RAM each)
- **Database**: db.m5.4xlarge (16 vCPU, 64 GB RAM)
- **Throughput**: 7.5 Hours of content will take approximately 1 hour to process

### Initial Terraform State Directory

The `initial-state/` directory contains Terraform configurations for creating the S3 state buckets required for remote state storage. This is a **prerequisite step** that must be completed before deploying the main infrastructure.

Each initial-state environment contains:

```
initial-state/your-company/
├── main.tf               # S3 state bucket module configuration
├── providers.tf          # AWS provider configuration
└── outputs.tf            # Bucket information outputs
```

**Purpose**: Creates encrypted S3 buckets with versioning for Teraform state locking, providing a secure foundation for Terraform remote state management.

**Usage**:
```bash
cd initial-state/your-company
terraform init
terraform apply
```

### Environment Directory Structure

Each environment contains:

```
your-environment/
├── backend.tf            # Terraform state backend configuration
├── main.tf              # Main infrastructure resources
├── provider.tf          # AWS, Kubernetes, and Helm providers
├── variables.tf         # Variable definitions
└── your-env.tfvars      # Environment-specific values
```

### Secrets Management

The reference implementation use AWS Secrets Manager with the [AWS ASCP Provider](https://docs.aws.amazon.com/secretsmanager/latest/userguide/ascp-eks-installation.html) installed as an EKS add on.

This will:
- Create an IAM policy to allow access to specific secrets (`match-docker-secret` and secrets beginning with your chosen secret naming convention)
- Inject the elasticache config details into a secret in AWS Secrets Manager after creation
- Inject the RDS config details into a secret in AWS Secrets Manager after creation

## Prerequisites

You will need to create a secret in AWS Secrets Manager with your docker auth token called `match-docker-secret`

```bash
aws secretsmanager create-secret \
--name match-docker-secret \
--description "Docker Hub credentials (dockerconfigjson)" \
--region ${your-region} \
--add-replica-regions Region=${your-replicate-region} \
--secret-string $SECRET_JSON
```

```hcl
module "iam_role_for_service_account" {
  source                     = "git::https://github.com/ad-signalio/terraform-utils-private.git//aws/tf-hosted-modules/tf-dt-iam-roles?ref=v0.0.36-aws-tf-hosted-modules-tf-dt-iam-roles"
  s3_bucket_name             = "${local.cluster_name}-primary"
  env_name                   = var.env_name
  tags                       = var.tags
  oidc_provider_arn          = module.eks.eks_cluster.oidc_provider_arn
  oidc_issuer_url            = module.eks.eks_cluster.cluster_oidc_issuer_url
  kubernetes_namespace       = var.k8s_namespace
  kubernetes_service_account = "adsignal-match"
  domain_name                = var.external_domain
  adsignal_org               = "autoingest"
  ## if you don't wish to allow access to AWS Secret Manager,
  ## set allow_aws_secret_manager_access to false
  ## allow_aws_secret_manager_access = false
  ## and remove secret_naming_convention var
  secret_naming_convention   = var.env_name
}

module "elasticache_redis" {
  source                   = "git::https://github.com/ad-signalio/terraform-utils-private.git//aws/tf-hosted-modules/tf-dt-elasticache-redis?ref=v0.0.35-aws-tf-hosted-modules-tf-dt-elasticache-redis"
  env_name                 = var.env_name
  tags                     = var.tags
  vpc                      = module.vpc.vpc
  az                       = var.availability_zone_name
  private_subnets          = module.vpc.private_subnets
  cidr_block               = module.vpc.vpc_cidr_block
  ## if you don't wish to allow access to AWS Secret Manager,
  ## set create_aws_secret to false
  ## create_aws_secret = false
  ## and remove secret_naming_convention var
  secret_naming_convention = var.env_name

  depends_on = [module.eks]
}

module "rds-postgres" {
  source                   = "git::https://github.com/ad-signalio/terraform-utils-private.git//aws/tf-hosted-modules/tf-dt-rds-pg?ref=v0.0.35-aws-tf-hosted-modules-tf-dt-rds-pg"
  env_name                 = var.env_name
  tags                     = var.tags
  subnet_ids               = tolist(module.vpc.private_subnets)
  instance_class           = var.rds_instance_class
  allocated_storage        = 20
  max_allocated_storage    = 100
  vpc_security_group_ids   = [module.eks.eks_cluster_node_sg]
  k8s_namespace            = var.k8s_namespace
  ## if you don't wish to allow access to AWS Secret Manager,
  ## set create_aws_secret to false
  ## create_aws_secret = false
  ## and remove secret_naming_convention var
  secret_naming_convention = var.env_name
  depends_on               = [module.eks]

  deletion_protection = false
}
```

## Configuration

### Key Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| **Core Infrastructure** |
| `env_name` | Environment name | - | `small-example-project`, `prod-acme-corp` |
| **AWS Configuration** |
| `region` | AWS region | `us-east-1` | `us-west-2`, `eu-west-1` |
| `availability_zone_name` | Specific AZ for single-zone resources | - | `us-east-1a` |
| `cidr` | VPC CIDR block | `10.25.0.0/16` | `10.0.0.0/16` |
| **EKS Configuration** |
| `eks_compute_nodes` | Number of worker nodes | `2` | `3`, `5` |
| `eks_compute_node_type` | EC2 instance type | `t3.2xlarge` | `t3.large`, `m5.xlarge` |
| **Database Configuration** |
| `rds_instance_class` | RDS PostgreSQL instance class | `db.t3.small` | `db.t3.medium`, `db.r5.large` |
| **Storage Configuration** |
| `storage_shared_storage_size` | EFS shared storage volume size | `100Gi` | `500Gi`, `1Ti` |
| **Application Configuration** |
| `external_domain` | Application domain | `test-company.sbox.as-priv.net` | `myapp.prod.as-priv.net` |
| `k8s_namespace` | Kubernetes namespace | `match` | `production` |

### Example Configuration

```hcl
# your-env.tfvars
# Core Infrastructure
env_name = "prod-your-company"

# AWS Configuration
region                 = "us-east-1"
availability_zone_name = "us-east-1a"

# Network Configuration
cidr            = "10.25.0.0/16"
external_domain = "your-company.prod.as-priv.net"

# EKS Configuration
eks_compute_nodes     = 3
eks_compute_node_type = "t3.large"

# Database Configuration
rds_instance_class = "db.t3.medium"

# Storage Configuration
storage_shared_storage_size = "500Gi"

# Application Configuration
k8s_namespace = "production"
```