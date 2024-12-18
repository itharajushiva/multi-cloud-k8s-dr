output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "velero_s3_bucket" {
  value = module.storage.s3_bucket_name
}

output "velero_irsa_role_arn" {
  value = module.storage.velero_role_arn
}

output "configure_kubectl_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
