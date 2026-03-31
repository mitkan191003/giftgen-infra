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
  default = "shared"
}

variable "name_prefix" {
  type    = string
  default = ""
}

variable "repository_namespace" {
  type    = string
  default = ""
}

variable "github_repository_full_name" {
  type = string
}

variable "github_connection_arn" {
  type    = string
  default = ""
}

variable "github_connection_name" {
  type    = string
  default = ""
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

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "pipelines" {
  type = map(object({
    branch                    = string
    enable_argocd_refresh     = optional(bool, true)
    argocd_server             = optional(string, "")
    argocd_application_name   = optional(string, "giftgen")
    argocd_deploy_secret_name = optional(string, "")
  }))
  default = {
    dev = {
      branch                    = "dev"
      argocd_server             = "https://argocd.giftgen-dev.mithrak.com"
      argocd_application_name   = "giftgen"
      argocd_deploy_secret_name = "giftgen-dev/argocd-deploy"
    }
    prod = {
      branch                    = "main"
      argocd_server             = "https://argocd-giftgen.mithrak.com"
      argocd_application_name   = "giftgen"
      argocd_deploy_secret_name = "giftgen-prod/argocd-deploy"
    }
  }
}
