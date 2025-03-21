output "argocd_namespace" {
  value = module.cluster_bootstrap.argocd_namespace
}

output "system_namespace" {
  value = module.cluster_bootstrap.system_namespace
}

output "application_namespace" {
  value = module.cluster_bootstrap.application_namespace
}

output "application_service_account_role_arn" {
  value = module.cluster_bootstrap.application_service_account_role_arn
}

output "argocd_url" {
  value = module.cluster_bootstrap.argocd_url
}

output "external_dns_namespace" {
  value = module.cluster_bootstrap.external_dns_namespace
}

output "external_secrets_namespace" {
  value = module.cluster_bootstrap.external_secrets_namespace
}

output "application_repo_url" {
  value = var.application_repo_url
}

output "application_target_revision" {
  value = var.application_target_revision
}

output "application_chart_path" {
  value = var.application_chart_path
}

output "application_value_file" {
  value = var.application_value_file
}

output "cleanup_schedule" {
  value = var.cleanup_schedule
}
