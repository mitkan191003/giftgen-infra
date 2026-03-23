output "name" {
  value = local.name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "assets_bucket_name" {
  value = aws_s3_bucket.assets.bucket
}

output "generation_queue_url" {
  value = aws_sqs_queue.generation.url
}

output "generation_queue_arn" {
  value = aws_sqs_queue.generation.arn
}

output "backend_api_repository_url" {
  value = aws_ecr_repository.backend_api.repository_url
}

output "backend_api_repository_name" {
  value = aws_ecr_repository.backend_api.name
}

output "backend_api_repository_arn" {
  value = aws_ecr_repository.backend_api.arn
}

output "backend_worker_repository_url" {
  value = aws_ecr_repository.backend_worker.repository_url
}

output "backend_worker_repository_name" {
  value = aws_ecr_repository.backend_worker.name
}

output "backend_worker_repository_arn" {
  value = aws_ecr_repository.backend_worker.arn
}

output "modal_secret_arn" {
  value = aws_secretsmanager_secret.modal.arn
}

output "modal_secret_name" {
  value = aws_secretsmanager_secret.modal.name
}

output "openai_secret_arn" {
  value = aws_secretsmanager_secret.openai.arn
}

output "openai_secret_name" {
  value = aws_secretsmanager_secret.openai.name
}

output "cloudflare_secret_arn" {
  value = aws_secretsmanager_secret.cloudflare.arn
}

output "cloudflare_secret_name" {
  value = aws_secretsmanager_secret.cloudflare.name
}

output "argocd_github_app_secret_arn" {
  value = aws_secretsmanager_secret.argocd_github_app.arn
}

output "argocd_github_app_secret_name" {
  value = aws_secretsmanager_secret.argocd_github_app.name
}

output "argocd_deploy_secret_arn" {
  value = aws_secretsmanager_secret.argocd_deploy.arn
}

output "argocd_deploy_secret_name" {
  value = aws_secretsmanager_secret.argocd_deploy.name
}

output "database_endpoint" {
  value = module.postgres.db_instance_endpoint
}

output "database_name" {
  value = var.db_name
}

output "database_secret_arn" {
  value = module.postgres.db_instance_master_user_secret_arn
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.frontend.id
}

output "cognito_domain" {
  value = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}

output "api_certificate_arn" {
  value = local.create_api_dns ? aws_acm_certificate_validation.api[0].certificate_arn : null
}

output "argocd_certificate_arn" {
  value = local.create_argocd_dns ? aws_acm_certificate_validation.argocd[0].certificate_arn : null
}

output "frontend_hostname" {
  value = var.frontend_hostname != "" ? var.frontend_hostname : null
}

output "api_hostname" {
  value = var.api_hostname != "" ? var.api_hostname : null
}

output "argocd_hostname" {
  value = local.argocd_hostname != "" ? local.argocd_hostname : null
}

output "cloudflare_zone_id" {
  value = var.cloudflare_zone_id != "" ? var.cloudflare_zone_id : null
}
