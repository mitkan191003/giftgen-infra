locals {
  name                     = "${var.project}-${var.environment}"
  oidc_hostpath            = trimprefix(var.cluster_oidc_issuer_url, "https://")
  runtime_environment_name = lookup({ dev = "development", prod = "production" }, var.environment, var.environment)
  create_api_canary        = var.enable_api_canary && var.api_hostname != ""
  alb_access_logs_prefix   = "${var.project}/${var.environment}/api"
  application_log_groups = {
    application = "/aws/containerinsights/${var.cluster_name}/application"
    dataplane   = "/aws/containerinsights/${var.cluster_name}/dataplane"
    host        = "/aws/containerinsights/${var.cluster_name}/host"
    performance = "/aws/containerinsights/${var.cluster_name}/performance"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "container_insights" {
  for_each = local.application_log_groups

  name              = each.value
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "cloudwatch_observability_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:${var.cloudwatch_namespace}:cloudwatch-agent"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_observability" {
  name               = "${local.name}-cloudwatch-observability"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_observability_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_observability.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "xray_write" {
  role       = aws_iam_role.cloudwatch_observability.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name             = var.cluster_name
  addon_name               = "amazon-cloudwatch-observability"
  service_account_role_arn = aws_iam_role.cloudwatch_observability.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_iam_role_policy_attachment.cloudwatch_agent,
    aws_iam_role_policy_attachment.xray_write,
    aws_cloudwatch_log_group.container_insights,
  ]
}

resource "aws_s3_bucket" "alb_access_logs" {
  bucket = "${local.name}-${data.aws_caller_identity.current.account_id}-${var.region}-alb-logs"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_access_logs" {
  bucket                  = aws_s3_bucket.alb_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id

  rule {
    id     = "expire-alb-access-logs"
    status = "Enabled"

    filter {
      prefix = local.alb_access_logs_prefix
    }

    expiration {
      days = var.alb_access_logs_retention_days
    }
  }
}

data "aws_iam_policy_document" "alb_access_logs" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.alb_access_logs.arn}/${local.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id
  policy = data.aws_iam_policy_document.alb_access_logs.json
}

resource "aws_s3_bucket" "canary_artifacts" {
  count = local.create_api_canary ? 1 : 0

  bucket = "${local.name}-${data.aws_caller_identity.current.account_id}-${var.region}-synthetics"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "canary_artifacts" {
  count = local.create_api_canary ? 1 : 0

  bucket = aws_s3_bucket.canary_artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "canary_artifacts" {
  count = local.create_api_canary ? 1 : 0

  bucket                  = aws_s3_bucket.canary_artifacts[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "canary_artifacts" {
  count = local.create_api_canary ? 1 : 0

  bucket = aws_s3_bucket.canary_artifacts[0].id

  rule {
    id     = "expire-canary-artifacts"
    status = "Enabled"

    filter {
      prefix = "artifacts/"
    }

    expiration {
      days = var.canary_artifacts_retention_days
    }
  }
}

data "archive_file" "api_canary" {
  count = local.create_api_canary ? 1 : 0

  type        = "zip"
  output_path = "/tmp/${local.name}-api-canary.zip"

  source {
    filename = "index.mjs"
    content = templatefile("${path.module}/templates/api-canary.js.tpl", {
      api_hostname = var.api_hostname
    })
  }
}

data "aws_iam_policy_document" "canary_assume_role" {
  count = local.create_api_canary ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "canary" {
  count = local.create_api_canary ? 1 : 0

  name               = "${local.name}-api-canary"
  assume_role_policy = data.aws_iam_policy_document.canary_assume_role[0].json
}

data "aws_iam_policy_document" "canary" {
  count = local.create_api_canary ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "cloudwatch:PutMetricData",
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.canary_artifacts[0].arn}/*"]
  }

  statement {
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "canary" {
  count = local.create_api_canary ? 1 : 0

  name   = "${local.name}-api-canary"
  policy = data.aws_iam_policy_document.canary[0].json
}

resource "aws_iam_role_policy_attachment" "canary" {
  count = local.create_api_canary ? 1 : 0

  role       = aws_iam_role.canary[0].name
  policy_arn = aws_iam_policy.canary[0].arn
}

resource "aws_synthetics_canary" "api_health" {
  count = local.create_api_canary ? 1 : 0

  name                 = "${local.name}-api-health"
  artifact_s3_location = "s3://${aws_s3_bucket.canary_artifacts[0].bucket}/artifacts/"
  execution_role_arn   = aws_iam_role.canary[0].arn
  handler              = "index.handler"
  runtime_version      = "syn-nodejs-3.1"
  start_canary         = true
  zip_file             = data.archive_file.api_canary[0].output_path

  schedule {
    expression = var.api_canary_schedule_expression
  }

  run_config {
    timeout_in_seconds = 60
    active_tracing     = false
  }

  success_retention_period = 30
  failure_retention_period = 30

  depends_on = [
    aws_iam_role_policy_attachment.canary,
    aws_s3_bucket_lifecycle_configuration.canary_artifacts,
  ]
}

resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count = var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_cloudwatch_metric_alarm" "generation_failures" {
  alarm_name          = "${local.name}-generation-failures"
  alarm_description   = "Generation jobs are failing in ${var.environment}"
  namespace           = var.metric_namespace
  metric_name         = "GenerationCompletedCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    Environment = local.runtime_environment_name
    Service     = "giftgen-worker"
    Outcome     = "failed"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name}-api-5xx"
  alarm_description   = "API is returning 5xx responses in ${var.environment}"
  namespace           = var.metric_namespace
  metric_name         = "HttpRequestCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    Environment = local.runtime_environment_name
    Service     = "giftgen-api"
    Operation   = "POST /api/v1/creations"
    Outcome     = "5xx"
  }
}

resource "aws_cloudwatch_metric_alarm" "auth_failures" {
  alarm_name          = "${local.name}-auth-failures"
  alarm_description   = "Authentication failures are elevated in ${var.environment}"
  namespace           = var.metric_namespace
  metric_name         = "AuthFailureCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    Environment = local.runtime_environment_name
    Service     = "giftgen-api"
    Outcome     = "invalid_token"
  }
}

resource "aws_cloudwatch_metric_alarm" "cleanup_failures" {
  alarm_name          = "${local.name}-cleanup-failures"
  alarm_description   = "Cleanup jobs are failing in ${var.environment}"
  namespace           = var.metric_namespace
  metric_name         = "CleanupRunCount"
  statistic           = "Sum"
  period              = 21600
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    Environment = local.runtime_environment_name
    Service     = "giftgen-cleanup"
    Outcome     = "failed"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name}-rds-cpu-high"
  alarm_description   = "RDS CPU is high in ${var.environment}"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.database_instance_identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${local.name}-rds-free-storage-low"
  alarm_description   = "RDS free storage is low in ${var.environment}"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2147483648
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.database_instance_identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "api_canary" {
  count = local.create_api_canary ? 1 : 0

  alarm_name          = "${local.name}-api-canary"
  alarm_description   = "Public API canary is failing in ${var.environment}"
  namespace           = "CloudWatchSynthetics"
  metric_name         = "SuccessPercent"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 100
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    CanaryName = aws_synthetics_canary.api_health[0].name
  }
}

locals {
  dashboard_widgets = concat(
    [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Generation Outcomes"
          view    = "timeSeries"
          stacked = false
          region  = var.region
          stat    = "Sum"
          metrics = [
            [var.metric_namespace, "GenerationCompletedCount", "Environment", local.runtime_environment_name, "Service", "giftgen-worker", "Outcome", "succeeded", { label = "Succeeded" }],
            [".", "GenerationCompletedCount", ".", ".", ".", ".", "Outcome", "failed", { label = "Failed" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Generation and Modal Latency"
          view   = "timeSeries"
          region = var.region
          stat   = "Average"
          metrics = [
            [var.metric_namespace, "GenerationDurationMs", "Environment", local.runtime_environment_name, "Service", "giftgen-worker", "Outcome", "succeeded", { label = "Generation duration" }],
            [".", "ModalRequestDurationMs", ".", ".", ".", ".", "Provider", "modal", "Outcome", "success", { label = "Modal duration" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "API Requests"
          view   = "timeSeries"
          region = var.region
          stat   = "Sum"
          metrics = [
            [var.metric_namespace, "HttpRequestCount", "Environment", local.runtime_environment_name, "Service", "giftgen-api", "Operation", "POST /api/v1/creations", "Outcome", "2xx", { label = "POST /creations 2xx" }],
            [".", "HttpRequestCount", ".", ".", ".", ".", ".", ".", "Outcome", "4xx", { label = "POST /creations 4xx" }],
            [".", "HttpRequestCount", ".", ".", ".", ".", ".", ".", "Outcome", "5xx", { label = "POST /creations 5xx" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Prompt Refinement and Auth Failures"
          view   = "timeSeries"
          region = var.region
          stat   = "Average"
          metrics = [
            [var.metric_namespace, "PromptRefinementDurationMs", "Environment", local.runtime_environment_name, "Service", "giftgen-api", "Provider", "stub", "Outcome", "success", { label = "Prompt refinement duration" }],
            [var.metric_namespace, "AuthFailureCount", "Environment", local.runtime_environment_name, "Service", "giftgen-api", "Outcome", "invalid_token", { label = "Auth failures", stat = "Sum", yAxis = "right" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Cleanup Activity"
          view   = "timeSeries"
          region = var.region
          stat   = "Sum"
          metrics = [
            [var.metric_namespace, "CleanupExpiredJobs", "Environment", local.runtime_environment_name, "Service", "giftgen-cleanup", { label = "Expired jobs" }],
            [".", "CleanupDeletedCreations", ".", ".", ".", ".", { label = "Deleted creations" }],
            [".", "CleanupDeletedAssets", ".", ".", ".", ".", { label = "Deleted assets" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "RDS Utilization"
          view   = "timeSeries"
          region = var.region
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.database_instance_identifier, { label = "CPU %" }],
            [".", "DatabaseConnections", ".", ".", { label = "Connections", yAxis = "right" }],
            [".", "FreeStorageSpace", ".", ".", { label = "Free storage bytes", stat = "Average" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "S3 Asset Storage"
          view   = "timeSeries"
          region = var.region
          stat   = "Average"
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", var.assets_bucket_name, "StorageType", "StandardStorage", { label = "Bucket size bytes" }],
            [".", "NumberOfObjects", ".", ".", "StorageType", "AllStorageTypes", { label = "Object count", yAxis = "right" }],
          ]
        }
      },
    ],
    local.create_api_canary ? [
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "Public API Canary"
          view   = "timeSeries"
          region = var.region
          stat   = "Average"
          metrics = [
            ["CloudWatchSynthetics", "SuccessPercent", "CanaryName", aws_synthetics_canary.api_health[0].name, { label = "Success %" }],
            [".", "Duration", ".", ".", { label = "Duration ms", yAxis = "right" }],
          ]
        }
      },
    ] : [],
  )
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name}-observability"
  dashboard_body = jsonencode({
    widgets = local.dashboard_widgets
  })
}
