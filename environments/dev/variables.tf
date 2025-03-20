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
