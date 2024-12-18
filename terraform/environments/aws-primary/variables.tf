variable "aws_region" {
  type        = string
  description = "AWS deployment region"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment stage"
  default     = "prod-primary"
}

variable "owner" {
  type        = string
  description = "Project owner"
  default     = "devops-dr-team"
}

variable "cluster_name" {
  type        = string
  description = "EKS Cluster Name"
  default     = "prod-eks-primary"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes Engine Version"
  default     = "1.29"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.100.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.100.1.0/24", "10.100.2.0/24", "10.100.3.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.100.10.0/24", "10.100.11.0/24", "10.100.12.0/24"]
}

variable "instance_types" {
  type        = list(string)
  default     = ["t3.xlarge"]
}

variable "desired_capacity" {
  type        = number
  default     = 3
}

variable "min_capacity" {
  type        = number
  default     = 2
}

variable "max_capacity" {
  type        = number
  default     = 6
}

variable "backup_bucket_name" {
  type        = string
  description = "Globally unique bucket name for primary DR backups"
  default     = "multicloud-dr-velero-backups-aws-prod"
}

variable "backup_retention_days" {
  type        = number
  default     = 90
}

variable "tags" {
  type        = map(string)
  default = {
    Environment = "prod-primary"
    Provider    = "AWS"
    Workload    = "Production-K8s"
  }
}
