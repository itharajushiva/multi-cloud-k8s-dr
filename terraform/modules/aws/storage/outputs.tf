output "s3_bucket_name" {
  description = "Velero backup S3 bucket name"
  value       = aws_s3_bucket.velero_backups.id
}

output "s3_bucket_arn" {
  description = "Velero backup S3 bucket ARN"
  value       = aws_s3_bucket.velero_backups.arn
}

output "velero_role_arn" {
  description = "IAM Role ARN to annotate Velero service account with"
  value       = aws_iam_role.velero.arn
}
