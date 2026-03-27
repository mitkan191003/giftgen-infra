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
  default = ""
}

variable "bootstrap_state_key" {
  type    = string
  default = ""
}

variable "shared_delivery_state_key" {
  type    = string
  default = ""
}
