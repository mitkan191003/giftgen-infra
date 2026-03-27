output "artifact_bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}

output "backend_api_repository_url" {
  value = aws_ecr_repository.backend_api.repository_url
}

output "backend_api_repository_name" {
  value = aws_ecr_repository.backend_api.name
}

output "backend_api_repository_arn" {
  value = aws_ecr_repository.backend_api.arn
}

output "backend_worker_repository_url" {
  value = aws_ecr_repository.backend_worker.repository_url
}

output "backend_worker_repository_name" {
  value = aws_ecr_repository.backend_worker.name
}

output "backend_worker_repository_arn" {
  value = aws_ecr_repository.backend_worker.arn
}

output "codebuild_project_name" {
  value = aws_codebuild_project.backend_images.name
}

output "deploy_codebuild_project_name" {
  value = local.any_argocd_refresh_enabled ? aws_codebuild_project.argocd_refresh[0].name : null
}

output "codepipeline_names" {
  value = {
    for name, pipeline in aws_codepipeline.backend_images : name => pipeline.name
  }
}

output "github_connection_arn" {
  value = local.github_connection_arn
}

output "github_connection_status" {
  value = var.github_connection_arn != "" ? "AVAILABLE" : aws_codestarconnections_connection.github[0].connection_status
}
