locals {
  name_prefix           = var.name_prefix != "" ? var.name_prefix : "${var.project}-${var.environment}"
  repository_namespace  = trimsuffix(trimprefix(var.repository_namespace != "" ? var.repository_namespace : var.project, "/"), "/")
  github_connection_arn = var.github_connection_arn != "" ? var.github_connection_arn : aws_codestarconnections_connection.github[0].arn
  pipelines = {
    for name, pipeline in var.pipelines : name => {
      branch                = pipeline.branch
      enable_argocd_refresh = try(pipeline.enable_argocd_refresh, true) && try(pipeline.argocd_server, "") != ""
      argocd_server         = try(pipeline.argocd_server, "")
      argocd_application_name = try(
        pipeline.argocd_application_name,
        "giftgen",
      )
      argocd_deploy_secret_name = try(pipeline.argocd_deploy_secret_name, "") != "" ? pipeline.argocd_deploy_secret_name : "${local.name_prefix}-${name}/argocd-deploy"
    }
  }
  argocd_deploy_secret_arn_patterns = [
    for pipeline in values(local.pipelines) :
    "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${pipeline.argocd_deploy_secret_name}*"
    if pipeline.enable_argocd_refresh
  ]
  any_argocd_refresh_enabled = length(local.argocd_deploy_secret_arn_patterns) > 0
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name_prefix}-backend-pipeline-${data.aws_caller_identity.current.account_id}-${var.region}"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_codestarconnections_connection" "github" {
  count = var.github_connection_arn == "" ? 1 : 0

  name          = var.github_connection_name != "" ? var.github_connection_name : "${local.name_prefix}-github"
  provider_type = "GitHub"
}

resource "aws_ecr_repository" "backend_api" {
  name                 = "${local.repository_namespace}/backend-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "backend_worker" {
  name                 = "${local.repository_namespace}/backend-worker"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "backend_api" {
  repository = aws_ecr_repository.backend_api.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain only the newest ${var.ecr_retention_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_retention_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "backend_worker" {
  repository = aws_ecr_repository.backend_worker.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain only the newest ${var.ecr_retention_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_retention_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${local.name_prefix}-backend-images-codebuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ArtifactBucket"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:PutObject",
    ]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*",
    ]
  }

  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PushBackendImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      aws_ecr_repository.backend_api.arn,
      aws_ecr_repository.backend_worker.arn,
    ]
  }

  dynamic "statement" {
    for_each = local.any_argocd_refresh_enabled ? [1] : []

    content {
      sid = "ReadArgoCdDeploySecret"
      actions = [
        "secretsmanager:GetSecretValue",
      ]
      resources = local.argocd_deploy_secret_arn_patterns
    }
  }
}

resource "aws_iam_policy" "codebuild" {
  name   = "${local.name_prefix}-backend-images-codebuild"
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild.arn
}

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${local.name_prefix}-backend-images"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "argocd_refresh" {
  count = local.any_argocd_refresh_enabled ? 1 : 0

  name              = "/aws/codebuild/${local.name_prefix}-argocd-refresh"
  retention_in_days = var.log_retention_days
}

resource "aws_codebuild_project" "backend_images" {
  name         = "${local.name_prefix}-backend-images"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = var.codebuild_environment_type
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }

    environment_variable {
      name  = "API_REPO_URI"
      value = aws_ecr_repository.backend_api.repository_url
    }

    environment_variable {
      name  = "WORKER_REPO_URI"
      value = aws_ecr_repository.backend_worker.repository_url
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild.name
      status     = "ENABLED"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.codebuild_buildspec
  }

  depends_on = [aws_iam_role_policy_attachment.codebuild]
}

resource "aws_codebuild_project" "argocd_refresh" {
  count        = local.any_argocd_refresh_enabled ? 1 : 0
  name         = "${local.name_prefix}-argocd-refresh"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = var.codebuild_environment_type
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false

    environment_variable {
      name  = "ARGOCD_SERVER"
      value = "https://argocd.invalid"
    }

    environment_variable {
      name  = "ARGOCD_APPLICATION"
      value = "giftgen"
    }

    environment_variable {
      name  = "ARGOCD_DEPLOY_SECRET"
      type  = "SECRETS_MANAGER"
      value = "giftgen/argocd-deploy"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.argocd_refresh[0].name
      status     = "ENABLED"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.argocd_deploy_buildspec
  }

  depends_on = [aws_iam_role_policy_attachment.codebuild]
}

data "aws_iam_policy_document" "codepipeline_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${local.name_prefix}-backend-images-codepipeline"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role.json
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    sid = "ArtifactBucket"
    actions = [
      "s3:GetBucketVersioning",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:PutObject",
    ]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*",
    ]
  }

  statement {
    sid = "UseCodeConnections"
    actions = [
      "codeconnections:UseConnection",
      "codestar-connections:UseConnection",
    ]
    resources = [local.github_connection_arn]
  }

  statement {
    sid = "InvokeCodeBuild"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]
    resources = compact([
      aws_codebuild_project.backend_images.arn,
      local.any_argocd_refresh_enabled ? aws_codebuild_project.argocd_refresh[0].arn : null,
    ])
  }
}

resource "aws_iam_policy" "codepipeline" {
  name   = "${local.name_prefix}-backend-images-codepipeline"
  policy = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline.arn
}

resource "aws_codepipeline" "backend_images" {
  for_each = local.pipelines

  name     = "${local.name_prefix}-backend-${each.key}"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      namespace        = "SourceVariables"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        ConnectionArn    = local.github_connection_arn
        FullRepositoryId = var.github_repository_full_name
        BranchName       = each.value.branch
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "BuildImages"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.backend_images.name
        EnvironmentVariables = jsonencode([
          {
            name  = "IMAGE_TAG"
            value = "#{SourceVariables.CommitId}"
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }

  dynamic "stage" {
    for_each = each.value.enable_argocd_refresh ? [1] : []

    content {
      name = "Deploy"

      action {
        name            = "RefreshArgoCd"
        category        = "Build"
        owner           = "AWS"
        provider        = "CodeBuild"
        version         = "1"
        input_artifacts = ["SourceArtifact"]

        configuration = {
          ProjectName = aws_codebuild_project.argocd_refresh[0].name
          EnvironmentVariables = jsonencode([
            {
              name  = "IMAGE_TAG"
              value = "#{SourceVariables.CommitId}"
              type  = "PLAINTEXT"
            },
            {
              name  = "SOURCE_COMMIT_ID"
              value = "#{SourceVariables.CommitId}"
              type  = "PLAINTEXT"
            },
            {
              name  = "ARGOCD_SERVER"
              value = each.value.argocd_server
              type  = "PLAINTEXT"
            },
            {
              name  = "ARGOCD_APPLICATION"
              value = each.value.argocd_application_name
              type  = "PLAINTEXT"
            },
            {
              name  = "ARGOCD_DEPLOY_SECRET"
              value = each.value.argocd_deploy_secret_name
              type  = "SECRETS_MANAGER"
            }
          ])
        }
      }
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.codepipeline,
    aws_s3_bucket_versioning.artifacts,
  ]
}
