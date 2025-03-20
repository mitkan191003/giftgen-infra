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

variable "api_image_tag" {
  type    = string
  default = "latest"
}

variable "worker_image_tag" {
  type    = string
  default = "latest"
}

variable "cleanup_schedule" {
  type    = string
  default = "0 */6 * * *"
}
