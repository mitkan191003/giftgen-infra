output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "system_namespace" {
  value = kubernetes_namespace.system.metadata[0].name
}

output "application_namespace" {
  value = kubernetes_namespace.application.metadata[0].name
}

output "application_service_account_role_arn" {
  value = aws_iam_role.application_runtime.arn
}

output "argocd_url" {
  value = local.argocd_url != "" ? local.argocd_url : null
}

output "external_dns_namespace" {
  value = kubernetes_namespace.external_dns.metadata[0].name
}

output "external_secrets_namespace" {
  value = kubernetes_namespace.external_secrets.metadata[0].name
}
