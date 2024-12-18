variable "cluster_name" {
  type        = string
  description = "EKS Cluster Name"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes Version"
  default     = "1.29"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where cluster is provisioned"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for node groups"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 Instance types for managed node pool"
  default     = ["t3.xlarge"]
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 3
}

variable "min_capacity" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 2
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 6
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
