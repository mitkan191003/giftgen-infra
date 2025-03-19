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

  cloudflare_zone_id    = var.cloudflare_zone_id
  frontend_hostname     = var.frontend_hostname
  frontend_cname_target = var.frontend_cname_target
  api_hostname          = var.api_hostname
  cognito_domain_prefix = var.cognito_domain_prefix
  cognito_callback_urls = var.cognito_callback_urls
  cognito_logout_urls   = var.cognito_logout_urls
}
