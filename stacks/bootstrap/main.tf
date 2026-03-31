provider "aws" {
  region = var.region
}

locals {
  core_state_key = var.core_state_key != "" ? var.core_state_key : "environments/${var.environment}/terraform.tfstate"
}

data "terraform_remote_state" "core" {
  backend = "s3"
  config = {
    bucket  = var.state_bucket_name
    key     = local.core_state_key
    region  = var.region
    encrypt = true
  }
}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.core.outputs.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.core.outputs.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

module "cluster_bootstrap" {
  source = "../../modules/cluster_bootstrap"

  project      = var.project
  environment  = var.environment
  region       = var.region
  cluster_name = data.terraform_remote_state.core.outputs.cluster_name

  cluster_oidc_issuer_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  oidc_provider_arn       = data.terraform_remote_state.core.outputs.oidc_provider_arn

  vpc_id                       = data.terraform_remote_state.core.outputs.vpc_id
  assets_bucket_name           = data.terraform_remote_state.core.outputs.assets_bucket_name
  database_name                = data.terraform_remote_state.core.outputs.database_name
  database_secret_arn          = data.terraform_remote_state.core.outputs.database_secret_arn
  modal_secret_arn             = data.terraform_remote_state.core.outputs.modal_secret_arn
  openai_secret_arn            = data.terraform_remote_state.core.outputs.openai_secret_arn
  cloudflare_secret_arn        = data.terraform_remote_state.core.outputs.cloudflare_secret_arn
  argocd_github_app_secret_arn = data.terraform_remote_state.core.outputs.argocd_github_app_secret_arn
  cognito_user_pool_id         = data.terraform_remote_state.core.outputs.cognito_user_pool_id
  cognito_user_pool_client_id  = data.terraform_remote_state.core.outputs.cognito_user_pool_client_id
  cognito_domain               = data.terraform_remote_state.core.outputs.cognito_domain
  cloudflare_zone_id           = data.terraform_remote_state.core.outputs.cloudflare_zone_id
  frontend_hostname            = coalesce(try(data.terraform_remote_state.core.outputs.frontend_hostname, null), "")
  api_hostname                 = coalesce(try(data.terraform_remote_state.core.outputs.api_hostname, null), "")
  api_certificate_arn          = coalesce(try(data.terraform_remote_state.core.outputs.api_certificate_arn, null), "")
  argocd_hostname              = coalesce(try(data.terraform_remote_state.core.outputs.argocd_hostname, null), "")
  argocd_certificate_arn       = coalesce(try(data.terraform_remote_state.core.outputs.argocd_certificate_arn, null), "")

  application_repo_url        = var.application_repo_url
  application_target_revision = var.application_target_revision
  application_chart_path      = var.application_chart_path
  application_value_file      = var.application_value_file
  cleanup_schedule            = var.cleanup_schedule
}

module "observability" {
  source = "../../modules/observability"

  project                      = var.project
  environment                  = var.environment
  region                       = var.region
  cluster_name                 = data.terraform_remote_state.core.outputs.cluster_name
  cluster_oidc_issuer_url      = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  oidc_provider_arn            = data.terraform_remote_state.core.outputs.oidc_provider_arn
  api_hostname                 = coalesce(try(data.terraform_remote_state.core.outputs.api_hostname, null), "")
  assets_bucket_name           = data.terraform_remote_state.core.outputs.assets_bucket_name
  database_instance_identifier = data.terraform_remote_state.core.outputs.database_instance_identifier

  metric_namespace                = var.metric_namespace
  log_retention_days              = var.observability_log_retention_days
  alb_access_logs_retention_days  = var.alb_access_logs_retention_days
  canary_artifacts_retention_days = var.canary_artifacts_retention_days
  enable_api_canary               = var.enable_api_canary
  api_canary_schedule_expression  = var.api_canary_schedule_expression
  notification_email              = var.alert_email

  depends_on = [module.cluster_bootstrap]
}
