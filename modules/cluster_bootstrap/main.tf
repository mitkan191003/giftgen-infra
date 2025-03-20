locals {
  runtime_environment = {
    dev     = "development"
    staging = "staging"
    prod    = "production"
  }

  environment_name       = lookup(local.runtime_environment, var.environment, var.environment)
  frontend_origin        = var.frontend_hostname != "" ? "https://${var.frontend_hostname}" : ""
  share_base_url         = var.frontend_hostname != "" ? "https://${var.frontend_hostname}/share" : ""
  app_enabled            = var.application_repo_url != ""
  oidc_hostpath          = trimprefix(var.cluster_oidc_issuer_url, "https://")
  application_value_file = var.application_value_file != "" ? var.application_value_file : "values-${var.environment}.yaml"
  argocd_ingress_enabled = var.argocd_hostname != "" && var.argocd_certificate_arn != ""
  argocd_url             = local.argocd_ingress_enabled ? "https://${var.argocd_hostname}" : ""
  ingress_enabled        = var.api_hostname != "" && var.api_certificate_arn != ""
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

  api_ingress_annotations = local.ingress_enabled ? {
    "alb.ingress.kubernetes.io/scheme"                    = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"               = "ip"
    "alb.ingress.kubernetes.io/listen-ports"              = "[{\"HTTP\":80},{\"HTTPS\":443}]"
    "alb.ingress.kubernetes.io/ssl-redirect"              = "443"
    "alb.ingress.kubernetes.io/certificate-arn"           = var.api_certificate_arn
    "alb.ingress.kubernetes.io/healthcheck-path"          = "/healthz"
    "external-dns.alpha.kubernetes.io/hostname"           = var.api_hostname
    "external-dns.alpha.kubernetes.io/cloudflare-proxied" = "false"
  } : {}

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

  application_values = {
    serviceAccount = {
      create = true
      name   = var.application_service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.application_runtime.arn
      }
    }
    config = {
      environment               = local.environment_name
      authMode                  = "cognito"
      corsOrigins               = compact([local.frontend_origin])
      publicShareBaseUrl        = local.share_base_url
      awsRegion                 = var.region
      assetStorageMode          = "s3"
      assetBucketName           = var.assets_bucket_name
      databaseName              = var.database_name
      databaseSecretId          = var.database_secret_arn
      modalSecretId             = var.modal_secret_arn
      openaiSecretId            = var.openai_secret_arn
      workerPollIntervalSeconds = var.worker_poll_interval_seconds
      cleanupRetentionDays      = var.cleanup_retention_days
      cognito = {
        region     = var.region
        userPoolId = var.cognito_user_pool_id
        clientId   = var.cognito_user_pool_client_id
        domain     = var.cognito_domain
      }
    }
    api = {
      image = {
        repository = var.backend_api_repository_url
        pullPolicy = "IfNotPresent"
      }
      ingress = {
        enabled     = local.ingress_enabled
        className   = "alb"
        annotations = local.api_ingress_annotations
        hosts = local.ingress_enabled ? [
          {
            host = var.api_hostname
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
              }
            ]
          }
        ] : []
      }
    }
    worker = {
      image = {
        repository = var.backend_worker_repository_url
        pullPolicy = "IfNotPresent"
      }
      intervalSeconds = var.worker_poll_interval_seconds
    }
    cleanup = {
      enabled  = true
      schedule = var.cleanup_schedule
      image = {
        repository = var.backend_worker_repository_url
        pullPolicy = "IfNotPresent"
      }
    }
    migrations = {
      enabled = true
      image = {
        repository = var.backend_api_repository_url
        pullPolicy = "IfNotPresent"
      }
    }
  }

  application_sync_policy = merge(
    {
      syncOptions = ["CreateNamespace=true"]
    },
    var.application_auto_sync ? {
      automated = {
        prune    = true
        selfHeal = true
      }
    } : {}
  )
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

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secretsmanager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = kubernetes_namespace.external_secrets.metadata[0].name
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

resource "kubernetes_manifest" "cloudflare_token_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "cloudflare-api-token"
      namespace = kubernetes_namespace.external_dns.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = kubernetes_manifest.cluster_secret_store.manifest.metadata.name
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "cloudflare-api-token"
        creationPolicy = "Owner"
        template = {
          engineVersion = "v2"
          data = {
            apiToken = "{{ .apiToken }}"
          }
        }
      }
      data = [
        {
          secretKey = "apiToken"
          remoteRef = {
            key      = var.cloudflare_secret_arn
            property = "apiToken"
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.cluster_secret_store]
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = var.external_dns_chart_version
  namespace        = kubernetes_namespace.external_dns.metadata[0].name
  create_namespace = false

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
    kubernetes_manifest.cloudflare_token_secret,
  ]
}

resource "kubernetes_manifest" "argocd_repository_secret" {
  count = local.app_enabled ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "${var.application_name}-repository"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = kubernetes_manifest.cluster_secret_store.manifest.metadata.name
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "${var.application_name}-repository"
        creationPolicy = "Owner"
        template = {
          engineVersion = "v2"
          metadata = {
            labels = {
              "argocd.argoproj.io/secret-type" = "repository"
            }
          }
          data = {
            type                    = "git"
            url                     = var.application_repo_url
            githubAppID             = "{{ .githubAppID }}"
            githubAppInstallationID = "{{ .githubAppInstallationID }}"
            githubAppPrivateKey     = "{{ .githubAppPrivateKey }}"
          }
        }
      }
      data = [
        {
          secretKey = "githubAppID"
          remoteRef = {
            key      = var.argocd_github_app_secret_arn
            property = "githubAppID"
          }
        },
        {
          secretKey = "githubAppInstallationID"
          remoteRef = {
            key      = var.argocd_github_app_secret_arn
            property = "githubAppInstallationID"
          }
        },
        {
          secretKey = "githubAppPrivateKey"
          remoteRef = {
            key      = var.argocd_github_app_secret_arn
            property = "githubAppPrivateKey"
          }
        }
      ]
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_manifest.cluster_secret_store,
  ]
}

resource "kubernetes_manifest" "application_project" {
  count = local.app_enabled ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = var.application_name
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      description = "GiftGen workloads managed by Terraform bootstrap"
      sourceRepos = [var.application_repo_url]
      destinations = [
        {
          namespace = kubernetes_namespace.application.metadata[0].name
          server    = "https://kubernetes.default.svc"
        }
      ]
      clusterResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        }
      ]
      namespaceResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_manifest" "application" {
  count = local.app_enabled ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.application_name
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      project = var.application_name
      source = {
        repoURL        = var.application_repo_url
        targetRevision = var.application_target_revision
        path           = var.application_chart_path
        helm = {
          valueFiles = [local.application_value_file]
          values     = yamlencode(local.application_values)
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.application.metadata[0].name
      }
      syncPolicy = local.application_sync_policy
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_manifest.argocd_repository_secret,
    kubernetes_manifest.application_project,
  ]
}
