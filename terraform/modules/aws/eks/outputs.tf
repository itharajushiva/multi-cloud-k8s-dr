output "cluster_name" {
  description = "EKS Cluster Name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane API"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "Issuer URL of the OIDC Provider"
  value       = aws_iam_openid_connect_provider.this.url
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = aws_eks_node_group.primary.arn
}
