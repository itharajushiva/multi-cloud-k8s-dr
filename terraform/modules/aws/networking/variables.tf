variable "environment" {
  type        = string
  description = "Deployment environment name (e.g. prod, staging, dr)"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster for resource tagging"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the AWS VPC"
  default     = "10.100.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets across AZs"
  default     = ["10.100.1.0/24", "10.100.2.0/24", "10.100.3.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets across AZs"
  default     = ["10.100.10.0/24", "10.100.11.0/24", "10.100.12.0/24"]
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
