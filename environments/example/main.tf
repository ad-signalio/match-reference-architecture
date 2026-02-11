locals {
  # Core naming and identification
  cluster_name = module.label.env_name
  app_url      = ["https://${var.external_domain}"]

  # Extra access entries configuration
  extra_access_entries = {
    github_actions = {
      principal_arn = "arn:aws:iam::203960437845:role/GitHubActions-helm-match"

      policy_associations = {
        match = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            namespaces = ["match"]
            type       = "namespace"
          }
        }
        clusterview = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            namespaces = []
            type       = "cluster"
          }
        }
      }
    }
  }
}
module "label" {
  source            = "git::https://github.com/ad-signalio/terraform-utils-private.git//generic/tf-hosted-modules/tf-dt-naming?ref=v0.0.59-generic-tf-hosted-modules-tf-dt-naming"
  env_use           = var.env_use
  env_id            = var.env_id
  env_additional_id = var.env_additional_id
  env_region        = var.env_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # AWS account and region information
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  # EFS subnet configuration
  efs_subnets_in_az = join(",", [
    for s in module.vpc.private_subnets_detail :
    s.id if s.availability_zone == var.availability_zone_name
  ])

  # Subnets in specific AZ for EKS
  subnets_in_az = [
    for s in module.vpc.private_subnets_detail :
    s.id if s.availability_zone == var.availability_zone_name
  ]
}

module "vpc" {
  source                  = "git::https://github.com/ad-signalio/terraform-utils.git?ref=aws/tf-hosted-modules/tf-dt-vpc/v1.0.0"
  env_name                = module.label.env_name
  tags                    = module.label.tags
  cidr                    = var.cidr
  availability_zone_count = 2
}

module "eks" {
  source = "git::https://github.com/ad-signalio/terraform-utils.git?ref=aws/tf-hosted-modules/tf-dt-eks/v1.0.4"

  env_name                 = module.label.env_name
  tags                     = module.label.tags
  subnets_in_az            = tolist(local.subnets_in_az)
  node_count               = var.eks_compute_nodes
  node_instance_type       = var.eks_compute_node_type
  vpc_id                   = module.vpc.vpc
  private_subnet_ids       = module.vpc.private_subnets
  iam_role_use_name_prefix = true
  vpc_cidr_block           = var.cidr

  admin_access_sso_permission_set_names = var.admin_access_sso_permission_set_names
  admin_access_role_names               = var.admin_access_role_names
  secret_naming_convention              = module.label.env_name
}


module "eks-load-balancer-controller" {
  source = "git::https://github.com/ad-signalio/terraform-utils.git?ref=aws/tf-hosted-modules/tf-dt-eks-aws-lb-ctrl/v1.0.0"

  env_name         = module.label.env_name
  tags             = module.label.tags
  eks_cluster      = module.eks.eks_cluster
  eks_cluster_auth = module.eks.eks_cluster_auth
  vpc              = module.vpc.vpc
  domain_name      = var.external_domain
  use_name_prefix  = true

  install_helm_charts = var.install_helm_charts
}

module "iam_role_for_service_account" {
  source = "git::https://github.com/ad-signalio/terraform-utils.git?ref=aws/tf-hosted-modules/tf-dt-iam-roles/v1.0.0"

  s3_bucket_name             = "${local.cluster_name}-primary"
  env_name                   = module.label.env_name
  tags                       = module.label.tags
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
  secret_naming_convention = module.label.env_name
}

module "elasticache_redis" {
  source = "git::https://github.com/ad-signalio/terraform-utils.git?ref=aws/tf-hosted-modules/tf-dt-elasticache-redis/v1.0.1"

  env_name        = module.label.env_name
  tags            = module.label.tags
  vpc             = module.vpc.vpc
  az              = var.availability_zone_name
  private_subnets = module.vpc.private_subnets
  cidr_block      = module.vpc.vpc_cidr_block
  ## if you don't wish to allow access to AWS Secret Manager,
  ## set create_aws_secret to false
  ## create_aws_secret = false
  ## and remove secret_naming_convention var
  secret_naming_convention = module.label.env_name

  depends_on = [module.eks]
}

module "rds-postgres" {
  source = "git::https://github.com/ad-signalio/terraform-utils.git?ref=aws/tf-hosted-modules/tf-dt-rds-pg/v1.0.1"

  env_name               = module.label.env_name
  tags                   = module.label.tags
  subnet_ids             = tolist(module.vpc.private_subnets)
  instance_class         = var.rds_instance_class
  allocated_storage      = 20
  max_allocated_storage  = 100
  vpc_security_group_ids = [module.eks.eks_cluster_node_sg]
  k8s_namespace          = var.k8s_namespace
  ## if you don't wish to allow access to AWS Secret Manager,
  ## set create_aws_secret to false
  ## create_aws_secret = false
  ## and remove secret_naming_convention var
  secret_naming_convention = module.label.env_name
  depends_on               = [module.eks]

  deletion_protection = false
}

module "efs" {
  source = "git::https://github.com/ad-signalio/terraform-utils.git?ref=aws/tf-hosted-modules/tf-dt-efs/v1.0.0"

  env_name                          = module.label.env_name
  tags                              = module.label.tags
  eks_cluster_endpoint              = module.eks.eks_cluster_endpoint
  eks_cluster_certificate           = module.eks.eks_cluster_certificate
  eks_cluster_token                 = module.eks.eks_cluster_token
  cluster_name_prefix               = local.cluster_name
  private_subnet                    = local.efs_subnets_in_az
  node_security_group_id            = module.eks.eks_cluster_node_sg
  availability_zone_name            = var.availability_zone_name
  storage_shared_storage_claim_name = "match-shared-storage"
  storage_shared_storage_size       = var.storage_shared_storage_size

}

module "s3-active-storage" {
  source = "git::https://github.com/ad-signalio/terraform-utils.git?ref=aws/tf-hosted-modules/tf-dt-s3-active-storage/v1.0.0"

  env_name = module.label.env_name
  app_url  = local.app_url
  tags     = module.label.tags
}
