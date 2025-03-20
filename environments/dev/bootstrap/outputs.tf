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
