terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }
  }

  # Production best practice: remote state in S3 with DynamoDB locking
  # backend "s3" {
  #   bucket         = "tf-state-dr-primary-us-east-1"
  #   key            = "aws-primary/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "multi-cloud-k8s-dr"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# Module: Networking (VPC, Subnets, Gateways, Routes)
module "networking" {
  source = "../../modules/aws/networking"

  environment          = var.environment
  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.tags
}

# Module: EKS Cluster & Managed Worker Node Pools
module "eks" {
  source = "../../modules/aws/eks"

  cluster_name       = var.cluster_name
  environment        = var.environment
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  instance_types     = var.instance_types
  desired_capacity   = var.desired_capacity
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
  tags               = var.tags
}

# Module: S3 Storage & IAM IRSA for Velero Backups
module "storage" {
  source = "../../modules/aws/storage"

  cluster_name          = var.cluster_name
  backup_bucket_name    = var.backup_bucket_name
  oidc_provider_arn     = module.eks.oidc_provider_arn
  oidc_provider_url     = module.eks.oidc_provider_url
  backup_retention_days = var.backup_retention_days
  tags                  = var.tags
}
