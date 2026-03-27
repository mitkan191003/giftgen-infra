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

output "application_auto_sync" {
  value = var.application_auto_sync
}

output "cleanup_schedule" {
  value = var.cleanup_schedule
}

output "metric_namespace" {
  value = var.metric_namespace
}

output "backend_log_level" {
  value = var.backend_log_level
}

output "backend_request_id_header_name" {
  value = var.backend_request_id_header_name
}

output "backend_sentry_dsn" {
  value = var.backend_sentry_dsn
}

output "backend_sentry_traces_sample_rate" {
  value = var.backend_sentry_traces_sample_rate
}

output "alert_topic_arn" {
  value = module.observability.alert_topic_arn
}

output "observability_dashboard_name" {
  value = module.observability.dashboard_name
}

output "alb_access_logs_bucket_name" {
  value = module.observability.alb_access_logs_bucket_name
}

output "alb_access_logs_prefix" {
  value = module.observability.alb_access_logs_prefix
}

output "container_insights_log_group_names" {
  value = module.observability.container_insights_log_group_names
}

output "api_canary_name" {
  value = module.observability.api_canary_name
}
