output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "system_namespace" {
  value = kubernetes_namespace.system.metadata[0].name
}
