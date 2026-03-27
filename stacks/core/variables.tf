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
  default = "dev"
}

variable "cluster_version" {
  type    = string
  default = "1.33"
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "cluster_public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "cloudflare_zone_id" {
  type    = string
  default = ""
}

variable "frontend_hostname" {
  type    = string
  default = ""
}

variable "frontend_cname_target" {
  type    = string
  default = "cname.vercel-dns.com"
}

variable "api_hostname" {
  type    = string
  default = ""
}

variable "argocd_hostname" {
  type    = string
  default = ""
}

variable "cognito_domain_prefix" {
  type = string
}

variable "cognito_callback_urls" {
  type = list(string)
}

variable "cognito_logout_urls" {
  type = list(string)
}

variable "cognito_password_minimum_length" {
  type    = number
  default = 7
}

variable "cognito_password_require_lowercase" {
  type    = bool
  default = false
}

variable "cognito_password_require_uppercase" {
  type    = bool
  default = false
}

variable "cognito_password_require_numbers" {
  type    = bool
  default = true
}

variable "cognito_password_require_symbols" {
  type    = bool
  default = false
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t4g.small"]
}

variable "node_ami_type" {
  type    = string
  default = "AL2023_ARM_64_STANDARD"
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_min_size" {
  type    = number
  default = 3
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "db_name" {
  type    = string
  default = "giftgen"
}

variable "db_username" {
  type    = string
  default = "giftgen"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 10
}

variable "db_max_allocated_storage" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_period" {
  type    = number
  default = 0
}

variable "deletion_protection" {
  type    = bool
  default = false
}
