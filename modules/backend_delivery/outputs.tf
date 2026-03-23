output "artifact_bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}

output "codebuild_project_name" {
  value = aws_codebuild_project.backend_images.name
}

output "deploy_codebuild_project_name" {
  value = local.argocd_refresh_enabled ? aws_codebuild_project.argocd_refresh[0].name : null
}

output "codepipeline_name" {
  value = aws_codepipeline.backend_images.name
}

output "github_connection_arn" {
  value = local.github_connection_arn
}

output "github_connection_status" {
  value = var.github_connection_arn != "" ? "AVAILABLE" : aws_codestarconnections_connection.github[0].connection_status
}
