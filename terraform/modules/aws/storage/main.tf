# AWS S3 Storage for Velero Backups & IRSA Role Configuration

resource "aws_s3_bucket" "velero_backups" {
  bucket        = var.backup_bucket_name
  force_destroy = false

  tags = merge(
    var.tags,
    {
      Name        = var.backup_bucket_name
      Purpose     = "Velero K8s Disaster Recovery"
      ManagedBy   = "Terraform"
    }
  )
}

# Enforce Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "velero" {
  bucket = aws_s3_bucket.velero_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "velero" {
  bucket = aws_s3_bucket.velero_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Versioning for safety
resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle rule to transition old backups to Glacier / expire after retention
resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = aws_s3_bucket.velero_backups.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.backup_retention_days
    }
  }
}

# IAM Policy for Velero backup & EBS snapshot operations
resource "aws_iam_policy" "velero" {
  name        = "${var.cluster_name}-velero-policy"
  description = "Permissions required by Velero for S3 storage and EBS volume snapshotting"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = [
          "${aws_s3_bucket.velero_backups.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.velero_backups.arn
        ]
      }
    ]
  })

  tags = var.tags
}

# IAM Role for Velero IRSA (IAM Role for Service Account)
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "velero" {
  name = "${var.cluster_name}-velero-sa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:velero:velero-server",
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "velero" {
  policy_arn = aws_iam_policy.velero.arn
  role       = aws_iam_role.velero.name
}
