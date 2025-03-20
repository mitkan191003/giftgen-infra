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
