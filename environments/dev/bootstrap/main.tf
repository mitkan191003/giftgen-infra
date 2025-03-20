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
  source = "../../../modules/cluster_bootstrap"

  project     = var.project
  environment = var.environment
  region      = var.region

  cluster_oidc_issuer_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  oidc_provider_arn       = data.terraform_remote_state.core.outputs.oidc_provider_arn

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
  frontend_hostname             = coalesce(try(data.terraform_remote_state.core.outputs.frontend_hostname, null), "")
  api_hostname                  = coalesce(try(data.terraform_remote_state.core.outputs.api_hostname, null), "")
  api_certificate_arn           = coalesce(try(data.terraform_remote_state.core.outputs.api_certificate_arn, null), "")

  application_repo_url        = var.application_repo_url
  application_target_revision = var.application_target_revision
  application_chart_path      = var.application_chart_path
  api_image_tag               = var.api_image_tag
  worker_image_tag            = var.worker_image_tag
  cleanup_schedule            = var.cleanup_schedule
}
