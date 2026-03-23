variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "giftgen"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "state_bucket_name" {
  type = string
}

variable "core_state_key" {
  type    = string
  default = "environments/dev/terraform.tfstate"
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
  default = "values-dev.yaml"
}

variable "application_auto_sync" {
  type    = bool
  default = false
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

variable "alert_email" {
  type    = string
  default = ""
}

variable "observability_log_retention_days" {
  type    = number
  default = 30
}

variable "alb_access_logs_retention_days" {
  type    = number
  default = 30
}

variable "canary_artifacts_retention_days" {
  type    = number
  default = 14
}

variable "enable_api_canary" {
  type    = bool
  default = true
}

variable "api_canary_schedule_expression" {
  type    = string
  default = "rate(5 minutes)"
}
