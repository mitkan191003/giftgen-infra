locals {
  name                             = "${var.project}-${var.environment}"
  github_connection_arn            = var.github_connection_arn != "" ? var.github_connection_arn : aws_codestarconnections_connection.github[0].arn
  argocd_deploy_secret_name        = var.argocd_deploy_secret_name != "" ? var.argocd_deploy_secret_name : "${local.name}/argocd-deploy"
  argocd_deploy_secret_arn_pattern = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${local.argocd_deploy_secret_name}*"
  argocd_refresh_enabled           = var.enable_argocd_refresh && var.argocd_server != ""
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name}-backend-pipeline-${data.aws_caller_identity.current.account_id}-${var.region}"
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

  name          = var.github_connection_name != "" ? var.github_connection_name : "${local.name}-github"
  provider_type = "GitHub"
}

resource "aws_ecr_lifecycle_policy" "backend_api" {
  repository = var.backend_api_repository_name
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
  repository = var.backend_worker_repository_name
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
  name               = "${local.name}-backend-images-codebuild"
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
      var.backend_api_repository_arn,
      var.backend_worker_repository_arn,
    ]
  }

  dynamic "statement" {
    for_each = local.argocd_refresh_enabled ? [1] : []

    content {
      sid = "ReadArgoCdDeploySecret"
      actions = [
        "secretsmanager:GetSecretValue",
      ]
      resources = [local.argocd_deploy_secret_arn_pattern]
    }
  }
}

resource "aws_iam_policy" "codebuild" {
  name   = "${local.name}-backend-images-codebuild"
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild.arn
}

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${local.name}-backend-images"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "argocd_refresh" {
  count = local.argocd_refresh_enabled ? 1 : 0

  name              = "/aws/codebuild/${local.name}-argocd-refresh"
  retention_in_days = var.log_retention_days
}

resource "aws_codebuild_project" "backend_images" {
  name         = "${local.name}-backend-images"
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
      value = var.backend_api_repository_url
    }

    environment_variable {
      name  = "WORKER_REPO_URI"
      value = var.backend_worker_repository_url
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
  count        = local.argocd_refresh_enabled ? 1 : 0
  name         = "${local.name}-argocd-refresh"
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
      value = var.argocd_server
    }

    environment_variable {
      name  = "ARGOCD_APPLICATION"
      value = var.argocd_application_name
    }

    environment_variable {
      name  = "ARGOCD_DEPLOY_SECRET"
      type  = "SECRETS_MANAGER"
      value = local.argocd_deploy_secret_name
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

  lifecycle {
    precondition {
      condition     = local.argocd_refresh_enabled
      error_message = "Argo CD refresh requires enable_argocd_refresh and argocd_server."
    }
  }
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
  name               = "${local.name}-backend-images-codepipeline"
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
      local.argocd_refresh_enabled ? aws_codebuild_project.argocd_refresh[0].arn : null,
    ])
  }
}

resource "aws_iam_policy" "codepipeline" {
  name   = "${local.name}-backend-images-codepipeline"
  policy = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline.arn
}

resource "aws_codepipeline" "backend_images" {
  name     = "${local.name}-backend-images"
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
        BranchName       = var.github_repository_branch
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
    for_each = local.argocd_refresh_enabled ? [1] : []

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
