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
