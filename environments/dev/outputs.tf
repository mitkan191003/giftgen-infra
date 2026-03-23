output "cluster_name" {
  value = module.core_platform.cluster_name
}

output "cluster_endpoint" {
  value = module.core_platform.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.core_platform.cluster_certificate_authority_data
  sensitive = true
}

output "oidc_provider_arn" {
  value = module.core_platform.oidc_provider_arn
}

output "vpc_id" {
  value = module.core_platform.vpc_id
}

output "assets_bucket_name" {
  value = module.core_platform.assets_bucket_name
}

output "backend_api_repository_url" {
  value = module.core_platform.backend_api_repository_url
}

output "backend_api_repository_name" {
  value = module.core_platform.backend_api_repository_name
}

output "backend_api_repository_arn" {
  value = module.core_platform.backend_api_repository_arn
}

output "backend_worker_repository_url" {
  value = module.core_platform.backend_worker_repository_url
}

output "backend_worker_repository_name" {
  value = module.core_platform.backend_worker_repository_name
}

output "backend_worker_repository_arn" {
  value = module.core_platform.backend_worker_repository_arn
}

output "database_name" {
  value = module.core_platform.database_name
}

output "database_endpoint" {
  value = module.core_platform.database_endpoint
}

output "database_secret_arn" {
  value = module.core_platform.database_secret_arn
}

output "modal_secret_arn" {
  value = module.core_platform.modal_secret_arn
}

output "openai_secret_arn" {
  value = module.core_platform.openai_secret_arn
}

output "cloudflare_secret_arn" {
  value = module.core_platform.cloudflare_secret_arn
}

output "cloudflare_secret_name" {
  value = module.core_platform.cloudflare_secret_name
}

output "argocd_github_app_secret_arn" {
  value = module.core_platform.argocd_github_app_secret_arn
}

output "argocd_github_app_secret_name" {
  value = module.core_platform.argocd_github_app_secret_name
}

output "argocd_deploy_secret_arn" {
  value = module.core_platform.argocd_deploy_secret_arn
}

output "argocd_deploy_secret_name" {
  value = module.core_platform.argocd_deploy_secret_name
}

output "cognito_user_pool_id" {
  value = module.core_platform.cognito_user_pool_id
}

output "cognito_user_pool_client_id" {
  value = module.core_platform.cognito_user_pool_client_id
}

output "cognito_domain" {
  value = module.core_platform.cognito_domain
}

output "api_certificate_arn" {
  value = module.core_platform.api_certificate_arn
}

output "argocd_certificate_arn" {
  value = module.core_platform.argocd_certificate_arn
}

output "frontend_hostname" {
  value = module.core_platform.frontend_hostname
}

output "api_hostname" {
  value = module.core_platform.api_hostname
}

output "argocd_hostname" {
  value = module.core_platform.argocd_hostname
}

output "cloudflare_zone_id" {
  value = module.core_platform.cloudflare_zone_id
}

output "backend_delivery_connection_arn" {
  value = var.enable_backend_delivery ? module.backend_delivery[0].github_connection_arn : null
}

output "backend_delivery_connection_status" {
  value = var.enable_backend_delivery ? module.backend_delivery[0].github_connection_status : null
}

output "backend_delivery_codebuild_project_name" {
  value = var.enable_backend_delivery ? module.backend_delivery[0].codebuild_project_name : null
}

output "backend_delivery_deploy_codebuild_project_name" {
  value = var.enable_backend_delivery ? module.backend_delivery[0].deploy_codebuild_project_name : null
}

output "backend_delivery_codepipeline_name" {
  value = var.enable_backend_delivery ? module.backend_delivery[0].codepipeline_name : null
}

output "backend_delivery_artifact_bucket_name" {
  value = var.enable_backend_delivery ? module.backend_delivery[0].artifact_bucket_name : null
}
