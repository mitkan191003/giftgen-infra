locals {
  runtime_environment = {
    dev     = "development"
    staging = "staging"
    prod    = "production"
  }
  environment_name = lookup(local.runtime_environment, var.environment, var.environment)
  frontend_origin  = var.frontend_hostname != "" ? "https://${var.frontend_hostname}" : ""
  share_base_url   = var.frontend_hostname != "" ? "https://${var.frontend_hostname}/share" : ""
  app_enabled      = var.application_repo_url != ""
  oidc_hostpath    = trimprefix(var.cluster_oidc_issuer_url, "https://")

  app_secret_arns = compact([
    var.database_secret_arn,
    var.modal_secret_arn,
    var.openai_secret_arn,
  ])

  ingress_enabled = var.api_hostname != "" && var.api_certificate_arn != ""
  ingress_annotations = local.ingress_enabled ? {
    "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"      = "ip"
    "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80},{\"HTTPS\":443}]"
    "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
    "alb.ingress.kubernetes.io/certificate-arn"  = var.api_certificate_arn
    "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
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
        tag        = var.api_image_tag
        pullPolicy = "IfNotPresent"
      }
      ingress = {
        enabled     = local.ingress_enabled
        className   = "alb"
        annotations = local.ingress_annotations
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
        tag        = var.worker_image_tag
        pullPolicy = "IfNotPresent"
      }
      intervalSeconds = var.worker_poll_interval_seconds
    }
    cleanup = {
      enabled  = true
      schedule = var.cleanup_schedule
      image = {
        repository = var.backend_worker_repository_url
        tag        = var.worker_image_tag
        pullPolicy = "IfNotPresent"
      }
    }
    migrations = {
      enabled = true
      image = {
        repository = var.backend_api_repository_url
        tag        = var.api_image_tag
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

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false

  values = [yamlencode({
    global = {
      domain = "argocd.local"
    }
    server = {
      service = {
        type = "ClusterIP"
      }
      extraArgs = ["--insecure"]
    }
  })]
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
          values = yamlencode(local.application_values)
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
    kubernetes_manifest.application_project,
  ]
}
