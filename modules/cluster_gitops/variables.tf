variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "argocd_namespace" {
  type = string
}

variable "application_namespace" {
  type = string
}

variable "external_dns_namespace" {
  type = string
}

variable "external_secrets_namespace" {
  type = string
}

variable "application_service_account_name" {
  type    = string
  default = "giftgen-runtime"
}

variable "application_service_account_role_arn" {
  type = string
}

variable "assets_bucket_name" {
  type = string
}

variable "backend_api_repository_url" {
  type = string
}

variable "backend_worker_repository_url" {
  type = string
}

variable "database_name" {
  type = string
}

variable "database_endpoint" {
  type = string
}

variable "database_secret_arn" {
  type = string
}

variable "modal_secret_arn" {
  type = string
}

variable "openai_secret_arn" {
  type = string
}

variable "cognito_user_pool_id" {
  type = string
}

variable "cognito_user_pool_client_id" {
  type = string
}

variable "cognito_domain" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "cloudflare_secret_arn" {
  type = string
}

variable "argocd_github_app_secret_arn" {
  type = string
}

variable "frontend_hostname" {
  type    = string
  default = ""
}

variable "api_hostname" {
  type    = string
  default = ""
}

variable "api_certificate_arn" {
  type    = string
  default = ""
}

variable "application_name" {
  type    = string
  default = "giftgen"
}

variable "application_repo_url" {
  type    = string
  default = ""
}

variable "application_target_revision" {
  type    = string
  default = "main"
}

variable "application_chart_path" {
  type    = string
  default = "helm/giftgen"
}

variable "application_value_file" {
  type    = string
  default = ""
}

variable "application_auto_sync" {
  type    = bool
  default = true
}

variable "worker_poll_interval_seconds" {
  type    = number
  default = 10
}

variable "cleanup_retention_days" {
  type    = number
  default = 7
}

variable "cleanup_schedule" {
  type    = string
  default = "0 */6 * * *"
}

variable "metric_namespace" {
  type    = string
  default = "GiftGen/Application"
}

variable "backend_log_level" {
  type    = string
  default = "INFO"
}

variable "backend_request_id_header_name" {
  type    = string
  default = "X-Request-Id"
}

variable "backend_sentry_dsn" {
  type    = string
  default = ""
}

variable "backend_sentry_traces_sample_rate" {
  type    = number
  default = 0.1
}

variable "alb_access_logs_bucket_name" {
  type    = string
  default = ""
}

variable "alb_access_logs_prefix" {
  type    = string
  default = ""
}
