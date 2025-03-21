locals {
  oidc_hostpath          = trimprefix(var.cluster_oidc_issuer_url, "https://")
  argocd_ingress_enabled = var.argocd_hostname != "" && var.argocd_certificate_arn != ""
  argocd_url             = local.argocd_ingress_enabled ? "https://${var.argocd_hostname}" : ""
  app_secret_arns        = compact([var.database_secret_arn, var.modal_secret_arn, var.openai_secret_arn])
  bootstrap_secret_arns  = compact([var.cloudflare_secret_arn, var.argocd_github_app_secret_arn])

  argocd_chart_values = yamlencode(merge(
    {
      fullnameOverride = "argocd"
      global = {
        domain = local.argocd_ingress_enabled ? var.argocd_hostname : "argocd.local"
      }
      server = {
        service = {
          type = "ClusterIP"
        }
        extraArgs = ["--insecure"]
      }
    },
    local.argocd_ingress_enabled ? {
      configs = {
        cm = {
          url = local.argocd_url
        }
      }
    } : {}
  ))

  argocd_ingress_annotations = local.argocd_ingress_enabled ? {
    "alb.ingress.kubernetes.io/scheme"                    = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"               = "ip"
    "alb.ingress.kubernetes.io/listen-ports"              = "[{\"HTTP\":80},{\"HTTPS\":443}]"
    "alb.ingress.kubernetes.io/ssl-redirect"              = "443"
    "alb.ingress.kubernetes.io/certificate-arn"           = var.argocd_certificate_arn
    "alb.ingress.kubernetes.io/backend-protocol"          = "HTTP"
    "alb.ingress.kubernetes.io/healthcheck-path"          = "/healthz"
    "external-dns.alpha.kubernetes.io/hostname"           = var.argocd_hostname
    "external-dns.alpha.kubernetes.io/cloudflare-proxied" = "false"
  } : {}
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "kubernetes_namespace" "system" {
  metadata {
    name = var.system_namespace
  }
}

resource "kubernetes_namespace" "application" {
  metadata {
    name = var.application_namespace
  }
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = var.external_dns_namespace
  }
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = var.external_secrets_namespace
  }
}

data "aws_iam_policy_document" "application_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:${var.application_namespace}:${var.application_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "application_runtime" {
  name               = "${var.project}-${var.environment}-application-runtime"
  assume_role_policy = data.aws_iam_policy_document.application_assume_role.json
}

data "aws_iam_policy_document" "application_runtime" {
  dynamic "statement" {
    for_each = length(local.app_secret_arns) > 0 ? [local.app_secret_arns] : []

    content {
      sid       = "ReadRuntimeSecrets"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = statement.value
    }
  }

  statement {
    sid       = "ListAssetsBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.assets_bucket_name}"]
  }

  statement {
    sid = "ManageAssets"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["arn:aws:s3:::${var.assets_bucket_name}/*"]
  }
}

resource "aws_iam_policy" "application_runtime" {
  name   = "${var.project}-${var.environment}-application-runtime"
  policy = data.aws_iam_policy_document.application_runtime.json
}

resource "aws_iam_role_policy_attachment" "application_runtime" {
  role       = aws_iam_role.application_runtime.name
  policy_arn = aws_iam_policy.application_runtime.arn
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${var.project}-${var.environment}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name   = "${var.project}-${var.environment}-aws-load-balancer-controller"
  policy = file("${path.module}/files/aws-load-balancer-controller-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

data "aws_iam_policy_document" "external_secrets_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:${var.external_secrets_namespace}:external-secrets"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.project}-${var.environment}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json
}

data "aws_iam_policy_document" "external_secrets" {
  dynamic "statement" {
    for_each = length(local.bootstrap_secret_arns) > 0 ? [local.bootstrap_secret_arns] : []

    content {
      sid = "ReadBootstrapSecrets"
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecretVersionIds",
      ]
      resources = statement.value
    }
  }
}

resource "aws_iam_policy" "external_secrets" {
  name   = "${var.project}-${var.environment}-external-secrets"
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = var.aws_load_balancer_controller_chart_version
  namespace        = "kube-system"
  create_namespace = false

  values = [yamlencode({
    clusterName = var.cluster_name
    region      = var.region
    vpcId       = var.vpc_id
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
      }
    }
  })]

  depends_on = [aws_iam_role_policy_attachment.aws_load_balancer_controller]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false

  values = [local.argocd_chart_values]
}

resource "kubernetes_ingress_v1" "argocd" {
  count = local.argocd_ingress_enabled ? 1 : 0

  metadata {
    name        = "argocd-server"
    namespace   = kubernetes_namespace.argocd.metadata[0].name
    annotations = local.argocd_ingress_annotations
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = var.argocd_hostname

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "argocd-server"

              port {
                name = "http"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    helm_release.aws_load_balancer_controller,
  ]
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_chart_version
  namespace        = kubernetes_namespace.external_secrets.metadata[0].name
  create_namespace = false

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      create = true
      name   = "external-secrets"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets.arn
      }
    }
  })]

  depends_on = [aws_iam_role_policy_attachment.external_secrets]
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = var.external_dns_chart_version
  namespace        = kubernetes_namespace.external_dns.metadata[0].name
  create_namespace = false
  wait             = false

  values = [yamlencode({
    provider = {
      name = "cloudflare"
    }
    sources    = ["ingress"]
    policy     = "sync"
    registry   = "txt"
    txtOwnerId = "${var.project}-${var.environment}"
    extraArgs = {
      "zone-id-filter"                  = var.cloudflare_zone_id
      "cloudflare-dns-records-per-page" = "5000"
    }
    env = [
      {
        name = "CF_API_TOKEN"
        valueFrom = {
          secretKeyRef = {
            name = "cloudflare-api-token"
            key  = "apiToken"
          }
        }
      }
    ]
  })]

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.external_secrets,
  ]
}
