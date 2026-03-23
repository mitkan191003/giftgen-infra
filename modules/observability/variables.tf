variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_oidc_issuer_url" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "api_hostname" {
  type    = string
  default = ""
}

variable "assets_bucket_name" {
  type = string
}

variable "database_instance_identifier" {
  type = string
}

variable "metric_namespace" {
  type    = string
  default = "GiftGen/Application"
}

variable "log_retention_days" {
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

variable "notification_email" {
  type    = string
  default = ""
}

variable "cloudwatch_namespace" {
  type    = string
  default = "amazon-cloudwatch"
}
