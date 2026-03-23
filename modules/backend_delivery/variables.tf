variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "github_repository_full_name" {
  type = string
}

variable "github_repository_branch" {
  type    = string
  default = "main"
}

variable "github_connection_arn" {
  type    = string
  default = ""
}

variable "github_connection_name" {
  type    = string
  default = ""
}

variable "backend_api_repository_url" {
  type = string
}

variable "backend_worker_repository_url" {
  type = string
}

variable "backend_api_repository_name" {
  type = string
}

variable "backend_worker_repository_name" {
  type = string
}

variable "backend_api_repository_arn" {
  type = string
}

variable "backend_worker_repository_arn" {
  type = string
}

variable "ecr_retention_count" {
  type    = number
  default = 3
}

variable "codebuild_compute_type" {
  type    = string
  default = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_environment_type" {
  type    = string
  default = "ARM_CONTAINER"
}

variable "codebuild_image" {
  type    = string
  default = "aws/codebuild/amazonlinux-aarch64-standard:3.0"
}

variable "codebuild_buildspec" {
  type    = string
  default = "buildspec.images.yml"
}

variable "enable_argocd_refresh" {
  type    = bool
  default = false
}

variable "argocd_server" {
  type    = string
  default = ""
}

variable "argocd_application_name" {
  type    = string
  default = "giftgen"
}

variable "argocd_deploy_secret_name" {
  type    = string
  default = ""
}

variable "argocd_deploy_buildspec" {
  type    = string
  default = "buildspec.deploy.yml"
}

variable "log_retention_days" {
  type    = number
  default = 14
}
