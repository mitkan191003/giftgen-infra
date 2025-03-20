variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "system_namespace" {
  type    = string
  default = "giftgen-system"
}

variable "argocd_chart_version" {
  type    = string
  default = "7.8.2"
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_oidc_issuer_url" {
  type = string
}

variable "oidc_provider_arn" {
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

variable "application_namespace" {
  type    = string
  default = "giftgen"
}

variable "application_service_account_name" {
  type    = string
  default = "giftgen-runtime"
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

variable "application_auto_sync" {
  type    = bool
  default = true
}

variable "api_image_tag" {
  type    = string
  default = "latest"
}

variable "worker_image_tag" {
  type    = string
  default = "latest"
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
