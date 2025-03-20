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

output "backend_worker_repository_url" {
  value = module.core_platform.backend_worker_repository_url
}

output "database_name" {
  value = module.core_platform.database_name
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
