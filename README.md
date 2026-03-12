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
- **KEDA** - Event-driven autoscaler for Kubernetes workloads
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

This reference architecture requires the following provider versions (as defined in `environments/example/infrastructure/provider.tf`):

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

**We recommend using AWS SSO IAM roles rather than IAM users using static credentials**

Please see comments in `main.tf` if you choose to use static credentials as a user instead of iam roles for AWS EKS authentication.

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
   git clone https://github.com/ad-signalio/match-reference-architecture.git
   cd match-reference-architecture
   ```

2. **Create environment directory**
   ```bash
   cp -r environments/example/infrastructure environments/your-company-name/infrastructure
   cd environments/your-company-name/infrastructure
   ```

3. **Configure variables**
   ```bash
   # Edit the  an example .tfvars file with your specific values
   cp <size>.tfvars your-company-name.tfvars
   vim your-company-name.tfvars
   # Edit the backend.tf to use your state bucket and statefile
   vim backend.tf

3. **Configure backend and remote state**
Bring your own remote state store or see [Terraform State](#terraform-state) to create an S3 bucket to use, or provide an existing S3 bucket.

Edit `environments/your-company-name/infrastructure/backend.tf` to use your state bucket and statefile
```
terraform {
  backend "s3" {
    bucket       = "my-s3-bucket"
    key          = "environments/example/infrastructure/s3/terraform.tfstate"
    region       = "your-region"
    use_lockfile = true
    encrypt      = true

  }
}
```

4. **Configure variables**
Configure the TFVARS for your environment, Configuration section https://github.com/ad-signalio/match-reference-architecture/tree/main?tab=readme-ov-file#configuration 


```bash
cp <size>.tfvars your-company-name.tfvars
vim your-company-name.tfvars
    vim main.tf

   ```

4. **Initialize and deploy**
   ```bash
   terraform init
   terraform plan -var-file="your-company-name.tfvars"
   terraform apply -var-file="your-company-name.tfvars"
   ```

### Terraform State

It's recommended you use a suitable [remote state](https://developer.hashicorp.com/terraform/language/state/remote) data store with Terraform.

The `initial-state/` directory contains a Terraform configurations for creating an S3 state bucket for remote terraform state storage. 


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

## Event Driven Autoscaling (KEDA)

[KEDA](https://keda.sh/) (Kubernetes Event-driven Autoscaling).

KEDA is installed by default as part of this reference architecture to enable autoscaling capabilities for the Match environment.

If you prefer to install KEDA through other methods (or map manage it separately), you can disable the automated installation by setting the `install_helm_charts` variable to `false`.

### Environment Directory Structure

Each environment contains:

```
your-environment/
├── backend.tf           # Terraform state backend configuration
├── main.tf              # Main infrastructure resources
├── outputs.tf           # Outputs useful info for deploying the match helm chart
├── provider.tf          # AWS, Kubernetes, and Helm providers
├── variables.tf         # Variable definitions
└── your-env.tfvars      # Environment-specific values
```

### Secrets Management

The reference implementation use AWS Secrets Manager with the [AWS ASCP Provider](https://docs.aws.amazon.com/secretsmanager/latest/userguide/ascp-eks-installation.html) installed as an EKS add on. 

The current infrastructure has secret creation "baked in" at different stages.

This will:
- [Create an IAM policy](https://github.com/ad-signalio/terraform-utils/blob/main/aws/tf-hosted-modules/tf-dt-eks/iam.tf) to allow access to specific secrets (`match-docker-secret` and secrets beginning with your chosen secret naming convention)
- Inject the [elasticache config details](https://github.com/ad-signalio/terraform-utils/blob/main/aws/tf-hosted-modules/tf-dt-elasticache-redis/main.tf) into a secret in AWS Secrets Manager after creation
- Inject the [RDS config details](https://github.com/ad-signalio/terraform-utils/blob/main/aws/tf-hosted-modules/tf-dt-rds-pg/main.tf) into a secret in AWS Secrets Manager after creation
- Create and inject [Owning User Credentials](https://github.com/ad-signalio/terraform-utils/blob/main/aws/tf-hosted-modules/tf-dt-application-secrets/main.tf) (the credentials you will log in to the product with). The user name will be the email you specify in the `owning_user_email` variable. Password will be auto generated and stored.
- Create and inject [API secrets](https://github.com/ad-signalio/terraform-utils/blob/main/aws/tf-hosted-modules/tf-dt-application-secrets/main.tf) (necessary for the code to run) into a secret in AWS Secrets Manager after creation

## Utilising ASCP Quick Start

In order to get the the necessary secrets for the Match application quickly, we have created an _optional_ helm chart: [secrets-configuration](https://github.com/ad-signalio/match-reference-architecture/tree/main/optional-add-ons/secrets-configuration).

The chart creates several Kubernetes SecretProviderClass resources that integrate with AWS Secrets Manager, allowing the Match application to securely access secrets stored in AWS without embedding them in the application code or Kubernetes manifests. It also creates a service account that will utilise the IAM role created [here](https://github.com/ad-signalio/terraform-utils/blob/main/aws/tf-hosted-modules/tf-dt-eks/iam.tf).

Please see the chart [README.md](https://github.com/ad-signalio/match-reference-architecture/blob/main/optional-add-ons/secrets-configuration/README.md) for installation instructions.

## Prerequisites: Manually created secrets 

You **must** manually create both the honeybadger and docker secrets in AWS Secrets Manager. 

1. Creating a secret in AWS Secrets Manager with your docker auth token called `match-docker-secret`

```bash
aws secretsmanager create-secret \
--name match-docker-secret \
--description "Docker Hub credentials (dockerconfigjson)" \
--region ${your-region} \
--add-replica-regions Region=${your-replicate-region} \
--secret-string $SECRET_JSON
```
2. Creating a secret in AWS Secrets Manager with your Honeybadger API token. This value will be provided securely by Snicket Labs to you.

```bash
aws secretsmanager create-secret \
--name match-honeybadger-secret \
--description "Honeybadger api secret" \
--region ${your-region} \
--add-replica-regions Region=${your-replicate-region} \
--secret-string $SECRET_API_KEY
```

## What this reference architecture does NOT include

- External DNS installation

You may use your own DNS solution by manually pointing a DNS CNAME at the Load Balancers DNS address once the match helm chart is installed and configured. See the Helm Chart [Readme](https://github.com/ad-signalio/helm-charts/blob/main/charts/match/README.md#dns) for more information. 

Optionally if you have a domain in Route53 you can may use our module to install [External DNS](https://kubernetes-sigs.github.io/external-dns/) onto the EKS cluster to create DNS entries for you.

Add the following to `infrastructure/main.tf`
```hcl
module "external_dns_iam" {
  source = "git::https://github.com/ad-signalio/terraform-utils.git?ref=aws/tf-hosted-modules/tf-dt-eks-aws-external-dns-ctrlr-iam/v1.0.0"

  oidc_provider_arn = module.eks.eks_cluster.oidc_provider_arn
  env_name          = module.label.env_name
  domain_name       = "your-base-domain"
  use_name_prefix   = true
}
```

This will create the IAM role and corresponding service account to assume the role to allow record management in route 53. 


```bash 
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
vi external-dns-config.yaml
env:
 - name: AWS_DEFAULT_REGION
   value: 
provider:
  name: aws
serviceAccount:
  create: false
  name: external-dns

helm upgrade --install external-dns external-dns/external-dns  -n kube-system -f external-dns-config.yaml
```

- Domain and certificate management

It is recommended you bring your own domain, and manage your own certificates. For a quick start, we would recommend registering and managing a domain in Route53.

- SMTP creation

Match will send passwords reset links and notifications to users via email if configured with SMTP credentials. This can be done with an SMTP username and password as kubernetes secrets and configured later when the helm chart is installed. 

If however an STMP service is required AWS SES can be used to provide SMTP credentials, we have not included this in the example `main.tf`.  

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
| **Database Configuration** |
| `rds_instance_class` | RDS PostgreSQL instance class | `db.t3.small` | `db.t3.medium`, `db.r5.large` |
| **Storage Configuration** |
| `storage_shared_storage_size` | EFS shared storage volume size | `100Gi` | `500Gi`, `1Ti` |
| **Application Configuration** |
| `external_domain` | Application domain | `test-company.sbox.as-priv.net` | `myapp.prod.as-priv.net` |
| `k8s_namespace` | Kubernetes namespace | `match` | `match` |
| `owning_user_email` | Email of the Admin user to access Match. | - | `ops@your-company.com` |
| **EKS Configuration** |
| `access_entries` | Map of extra Cluster access entries. | `{}` | `{ platform_admin = { principal_arn = "arn:aws:iam::123456789012:role/platform-admin" } }` |
| `secret_naming_convention` | Naming convention for secrets to be accessed by the service account. Recommend using org name as the secret naming convention. | - | `acme` |
| `use_auto_mode` | Boolean to choose whether to use EKS Auto Mode. | `true` | `false` |
| **Feature Configuration** |
| `install_helm_charts` | Enable installation of Helm charts (KEDA, LB Controller) | `true` | `false` |

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
external_domain = "your-company.your-company.domain"

# Database Configuration
rds_instance_class = "db.t3.medium"

# Storage Configuration
storage_shared_storage_size = "500Gi"

# Application Configuration
k8s_namespace = "match"
owning_user_email      = "admin@your-company.domain"
```
