provider "aws" {
  region = var.region
}

provider "cloudflare" {}

module "core_platform" {
  source = "../../modules/core_platform"

  project     = var.project
  environment = var.environment

  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  cloudflare_zone_id                 = var.cloudflare_zone_id
  frontend_hostname                  = var.frontend_hostname
  frontend_cname_target              = var.frontend_cname_target
  api_hostname                       = var.api_hostname
  argocd_hostname                    = var.argocd_hostname
  cognito_domain_prefix              = var.cognito_domain_prefix
  cognito_callback_urls              = var.cognito_callback_urls
  cognito_logout_urls                = var.cognito_logout_urls
  cognito_password_minimum_length    = var.cognito_password_minimum_length
  cognito_password_require_lowercase = var.cognito_password_require_lowercase
  cognito_password_require_uppercase = var.cognito_password_require_uppercase
  cognito_password_require_numbers   = var.cognito_password_require_numbers
  cognito_password_require_symbols   = var.cognito_password_require_symbols
}

module "backend_delivery" {
  count  = var.enable_backend_delivery ? 1 : 0
  source = "../../modules/backend_delivery"

  project     = var.project
  environment = var.environment
  region      = var.region

  github_repository_full_name = var.backend_repository_full_name
  github_repository_branch    = var.backend_repository_branch
  github_connection_arn       = var.backend_connection_arn
  github_connection_name      = var.backend_connection_name

  enable_argocd_refresh   = var.enable_argocd_refresh
  argocd_server           = module.core_platform.argocd_hostname != null ? "https://${module.core_platform.argocd_hostname}" : ""
  argocd_application_name = var.argocd_application_name

  backend_api_repository_url  = module.core_platform.backend_api_repository_url
  backend_api_repository_name = module.core_platform.backend_api_repository_name
  backend_api_repository_arn  = module.core_platform.backend_api_repository_arn

  backend_worker_repository_url  = module.core_platform.backend_worker_repository_url
  backend_worker_repository_name = module.core_platform.backend_worker_repository_name
  backend_worker_repository_arn  = module.core_platform.backend_worker_repository_arn
}
