terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}

locals {
  # AWS Partner Revenue Measurement tag. Empty unless
  # aws_marketplace_product_code is set. See docs/aws-marketplace-attribution.md.
  prm_tags = var.aws_marketplace_product_code == "" ? {} : {
    "aws-apn-id" = "pc:${var.aws_marketplace_product_code}"
  }
}

provider "aws" {
  region = var.region

  # Backstop for resources not passed module tags. Module tags are what reach
  # EC2 instances, via the EKS node group's launch template.
  default_tags {
    tags = local.prm_tags
  }
}

provider "kubernetes" {
  host                   = module.eks.eks_cluster_endpoint
  cluster_ca_certificate = module.eks.eks_cluster_certificate
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.eks_cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.eks_cluster_endpoint
    cluster_ca_certificate = module.eks.eks_cluster_certificate
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.eks_cluster_name]
      command     = "aws"
    }
  }
}