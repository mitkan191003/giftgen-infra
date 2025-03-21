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

variable "state_bucket_name" {
  type = string
}

variable "core_state_key" {
  type    = string
  default = "environments/dev/terraform.tfstate"
}

variable "bootstrap_state_key" {
  type    = string
  default = "environments/dev/bootstrap/terraform.tfstate"
}

