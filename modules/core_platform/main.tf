locals {
  name                = "${var.project}-${var.environment}"
  create_api_dns      = var.cloudflare_zone_id != "" && var.api_hostname != ""
  create_frontend_dns = var.cloudflare_zone_id != "" && var.frontend_hostname != "" && var.frontend_cname_target != ""
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = local.name
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.1"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  subnet_ids                           = module.vpc.private_subnets
  vpc_id                               = module.vpc.vpc_id
  authentication_mode                  = "API_AND_CONFIG_MAP"
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_public_access_cidrs

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      ami_type       = var.node_ami_type
    }
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds"
  description = "RDS access for GiftGen"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "rds_from_nodes" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = ["0.0.0.0/0"]
}

module "postgres" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.11.0"

  identifier = "${local.name}-postgres"

  engine               = "postgres"
  engine_version       = "16.4"
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage

  db_name  = var.db_name
  username = var.db_username
  port     = 5432

  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.rds.id]

  manage_master_user_password = true
  multi_az                    = var.db_multi_az
  backup_retention_period     = var.backup_retention_period
  storage_encrypted           = true
  publicly_accessible         = false
  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = !var.deletion_protection
}

resource "aws_s3_bucket" "assets" {
  bucket = "${local.name}-assets"
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    id     = "expire-temp-assets"
    status = "Enabled"

    filter {
      prefix = "temp/"
    }

    expiration {
      days = 7
    }
  }
}

resource "aws_sqs_queue" "generation_dlq" {
  name = "${local.name}-generation-dlq"
}

resource "aws_sqs_queue" "generation" {
  name = "${local.name}-generation"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.generation_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_ecr_repository" "backend_api" {
  name                 = "${local.name}/backend-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "backend_worker" {
  name                 = "${local.name}/backend-worker"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cognito_user_pool" "this" {
  name = "${local.name}-users"

  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
}

resource "aws_cognito_user_pool_client" "frontend" {
  name         = "${local.name}-frontend"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret              = false
  supported_identity_providers = ["COGNITO"]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = var.cognito_callback_urls
  logout_urls                          = var.cognito_logout_urls

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = var.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_acm_certificate" "api" {
  count             = local.create_api_dns ? 1 : 0
  domain_name       = var.api_hostname
  validation_method = "DNS"
}

resource "cloudflare_dns_record" "frontend" {
  count = local.create_frontend_dns ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = var.frontend_hostname
  type    = "CNAME"
  content = trimsuffix(var.frontend_cname_target, ".")
  ttl     = 1
  proxied = false
  comment = "GiftGen ${var.environment} frontend hostname"
}

resource "cloudflare_dns_record" "api_validation" {
  for_each = local.create_api_dns ? {
    for option in aws_acm_certificate.api[0].domain_validation_options :
    option.domain_name => {
      name   = trimsuffix(option.resource_record_name, ".")
      record = trimsuffix(option.resource_record_value, ".")
      type   = option.resource_record_type
    }
  } : {}

  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.record
  ttl     = 60
  proxied = false
  comment = "ACM validation for ${var.api_hostname}"
}

resource "aws_acm_certificate_validation" "api" {
  count = local.create_api_dns ? 1 : 0

  certificate_arn         = aws_acm_certificate.api[0].arn
  validation_record_fqdns = [for record in cloudflare_dns_record.api_validation : record.name]
}

resource "aws_secretsmanager_secret" "modal" {
  name = "${local.name}/modal"
}

resource "aws_secretsmanager_secret" "openai" {
  name = "${local.name}/openai"
}
