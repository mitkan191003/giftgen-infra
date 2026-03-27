provider "aws" {
  region = var.region
}

provider "cloudflare" {}

module "core_platform" {
  source = "../../modules/core_platform"

  project         = var.project
  environment     = var.environment
  cluster_version = var.cluster_version

  vpc_cidr                    = var.vpc_cidr
  azs                         = var.azs
  public_subnets              = var.public_subnets
  private_subnets             = var.private_subnets
  cluster_public_access_cidrs = var.cluster_public_access_cidrs
  node_instance_types         = var.node_instance_types
  node_ami_type               = var.node_ami_type
  node_desired_size           = var.node_desired_size
  node_min_size               = var.node_min_size
  node_max_size               = var.node_max_size

  db_name                  = var.db_name
  db_username              = var.db_username
  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_max_allocated_storage = var.db_max_allocated_storage
  db_multi_az              = var.db_multi_az
  backup_retention_period  = var.backup_retention_period
  deletion_protection      = var.deletion_protection

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
