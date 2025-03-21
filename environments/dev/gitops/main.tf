provider "aws" {
  region = var.region
}

data "terraform_remote_state" "core" {
  backend = "s3"
  config = {
    bucket  = var.state_bucket_name
    key     = var.core_state_key
    region  = var.region
    encrypt = true
  }
}

data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket  = var.state_bucket_name
    key     = var.bootstrap_state_key
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

module "cluster_gitops" {
  source = "../../../modules/cluster_gitops"

  project     = var.project
  environment = var.environment
  region      = var.region

  argocd_namespace                     = data.terraform_remote_state.bootstrap.outputs.argocd_namespace
  application_namespace                = data.terraform_remote_state.bootstrap.outputs.application_namespace
  external_dns_namespace               = data.terraform_remote_state.bootstrap.outputs.external_dns_namespace
  external_secrets_namespace           = data.terraform_remote_state.bootstrap.outputs.external_secrets_namespace
  application_service_account_role_arn = data.terraform_remote_state.bootstrap.outputs.application_service_account_role_arn

  assets_bucket_name            = data.terraform_remote_state.core.outputs.assets_bucket_name
  backend_api_repository_url    = data.terraform_remote_state.core.outputs.backend_api_repository_url
  backend_worker_repository_url = data.terraform_remote_state.core.outputs.backend_worker_repository_url
  database_name                 = data.terraform_remote_state.core.outputs.database_name
  database_secret_arn           = data.terraform_remote_state.core.outputs.database_secret_arn
  modal_secret_arn              = data.terraform_remote_state.core.outputs.modal_secret_arn
  openai_secret_arn             = data.terraform_remote_state.core.outputs.openai_secret_arn
  cognito_user_pool_id          = data.terraform_remote_state.core.outputs.cognito_user_pool_id
  cognito_user_pool_client_id   = data.terraform_remote_state.core.outputs.cognito_user_pool_client_id
  cognito_domain                = data.terraform_remote_state.core.outputs.cognito_domain
  cloudflare_zone_id            = data.terraform_remote_state.core.outputs.cloudflare_zone_id
  cloudflare_secret_arn         = data.terraform_remote_state.core.outputs.cloudflare_secret_arn
  argocd_github_app_secret_arn  = data.terraform_remote_state.core.outputs.argocd_github_app_secret_arn
  frontend_hostname             = coalesce(try(data.terraform_remote_state.core.outputs.frontend_hostname, null), "")
  api_hostname                  = coalesce(try(data.terraform_remote_state.core.outputs.api_hostname, null), "")
  api_certificate_arn           = coalesce(try(data.terraform_remote_state.core.outputs.api_certificate_arn, null), "")

  application_repo_url        = data.terraform_remote_state.bootstrap.outputs.application_repo_url
  application_target_revision = data.terraform_remote_state.bootstrap.outputs.application_target_revision
  application_chart_path      = data.terraform_remote_state.bootstrap.outputs.application_chart_path
  application_value_file      = data.terraform_remote_state.bootstrap.outputs.application_value_file
  cleanup_schedule            = data.terraform_remote_state.bootstrap.outputs.cleanup_schedule
}

