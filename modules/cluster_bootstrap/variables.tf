variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "system_namespace" {
  type    = string
  default = "giftgen-system"
}

variable "argocd_chart_version" {
  type    = string
  default = "7.8.2"
}
