provider "aws" {
  region = var.region
}

locals {
  codebuild_buildspec     = file("${path.module}/../../../backend/buildspec.images.yml")
  argocd_deploy_buildspec = file("${path.module}/../../../backend/buildspec.deploy.yml")
}

module "backend_delivery" {
  source = "../../modules/backend_delivery"

  project     = var.project
  environment = var.environment
  region      = var.region

  name_prefix          = var.name_prefix
  repository_namespace = var.repository_namespace

  github_repository_full_name = var.github_repository_full_name
  github_connection_arn       = var.github_connection_arn
  github_connection_name      = var.github_connection_name

  ecr_retention_count = var.ecr_retention_count

  codebuild_compute_type     = var.codebuild_compute_type
  codebuild_environment_type = var.codebuild_environment_type
  codebuild_image            = var.codebuild_image
  codebuild_buildspec        = local.codebuild_buildspec
  log_retention_days         = var.log_retention_days

  pipelines               = var.pipelines
  argocd_deploy_buildspec = local.argocd_deploy_buildspec
}
