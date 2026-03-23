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
  ingress_enabled        = var.api_hostname != "" && var.api_certificate_arn != ""
  access_logs_enabled    = var.alb_access_logs_bucket_name != ""
  application_value_file = var.application_value_file != "" ? var.application_value_file : "values-${var.environment}.yaml"

  api_ingress_annotations = local.ingress_enabled ? merge(
    {
      "alb.ingress.kubernetes.io/scheme"                    = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"               = "ip"
      "alb.ingress.kubernetes.io/listen-ports"              = "[{\"HTTP\":80},{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"              = "443"
      "alb.ingress.kubernetes.io/certificate-arn"           = var.api_certificate_arn
      "alb.ingress.kubernetes.io/healthcheck-path"          = "/healthz"
      "external-dns.alpha.kubernetes.io/hostname"           = var.api_hostname
      "external-dns.alpha.kubernetes.io/cloudflare-proxied" = "false"
    },
    local.access_logs_enabled ? {
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "access_logs.s3.enabled=true,access_logs.s3.bucket=${var.alb_access_logs_bucket_name},access_logs.s3.prefix=${var.alb_access_logs_prefix}"
    } : {}
  ) : {}

  application_values = {
    serviceAccount = {
      create = true
      name   = var.application_service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = var.application_service_account_role_arn
      }
    }
    config = {
      environment               = local.environment_name
      logLevel                  = var.backend_log_level
      metricNamespace           = var.metric_namespace
      requestIdHeaderName       = var.backend_request_id_header_name
      sentryDsn                 = var.backend_sentry_dsn
      sentryTracesSampleRate    = var.backend_sentry_traces_sample_rate
      authMode                  = "cognito"
      corsOrigins               = compact([local.frontend_origin])
      publicShareBaseUrl        = local.share_base_url
      awsRegion                 = var.region
      assetStorageMode          = "s3"
      assetBucketName           = var.assets_bucket_name
      databaseName              = var.database_name
      databaseEndpoint          = var.database_endpoint
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

  application_auto_sync_options = var.application_auto_sync ? tomap({
    automated = {
      prune    = true
      selfHeal = true
    }
    retry = {
      limit = 10
      backoff = {
        duration    = "30s"
        factor      = 2
        maxDuration = "10m"
      }
    }
  }) : tomap({})

  application_sync_policy = merge(
    {
      syncOptions = ["CreateNamespace=true"]
    },
    local.application_auto_sync_options,
  )
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
                namespace = var.external_secrets_namespace
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "cloudflare_token_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "cloudflare-api-token"
      namespace = var.external_dns_namespace
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

resource "kubernetes_manifest" "argocd_repository_secret" {
  count = local.app_enabled ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "${var.application_name}-repository"
      namespace = var.argocd_namespace
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

  depends_on = [kubernetes_manifest.cluster_secret_store]
}

resource "kubernetes_manifest" "application_project" {
  count = local.app_enabled ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = var.application_name
      namespace = var.argocd_namespace
    }
    spec = {
      description = "GiftGen workloads managed by Terraform gitops root"
      sourceRepos = [var.application_repo_url]
      destinations = [
        {
          namespace = var.application_namespace
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
}

resource "kubernetes_manifest" "application" {
  count = local.app_enabled ? 1 : 0

  computed_fields = [
    "spec.source.targetRevision",
    "spec.source.helm.parameters",
  ]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.application_name
      namespace = var.argocd_namespace
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
        namespace = var.application_namespace
      }
      syncPolicy = local.application_sync_policy
    }
  }

  depends_on = [
    kubernetes_manifest.argocd_repository_secret,
    kubernetes_manifest.application_project,
  ]
}
