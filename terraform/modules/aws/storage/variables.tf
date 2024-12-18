variable "cluster_name" {
  type        = string
  description = "EKS Cluster Name"
}

variable "backup_bucket_name" {
  type        = string
  description = "Unique S3 bucket name for Velero backups"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS OIDC provider"
}

variable "oidc_provider_url" {
  type        = string
  description = "Issuer URL of the EKS OIDC provider"
}

variable "backup_retention_days" {
  type        = number
  description = "Days before backup objects are permanently expired from S3"
  default     = 90
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
