output "argocd_namespace" {
  value = module.cluster_bootstrap.argocd_namespace
}

output "system_namespace" {
  value = module.cluster_bootstrap.system_namespace
}
