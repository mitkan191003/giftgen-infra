variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  type = string
}

variable "core_state_key" {
  type    = string
  default = "environments/dev/terraform.tfstate"
}
