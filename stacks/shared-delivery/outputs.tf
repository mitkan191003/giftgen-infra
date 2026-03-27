output "artifact_bucket_name" {
  value = module.backend_delivery.artifact_bucket_name
}

output "backend_api_repository_url" {
  value = module.backend_delivery.backend_api_repository_url
}

output "backend_api_repository_name" {
  value = module.backend_delivery.backend_api_repository_name
}

output "backend_api_repository_arn" {
  value = module.backend_delivery.backend_api_repository_arn
}

output "backend_worker_repository_url" {
  value = module.backend_delivery.backend_worker_repository_url
}

output "backend_worker_repository_name" {
  value = module.backend_delivery.backend_worker_repository_name
}

output "backend_worker_repository_arn" {
  value = module.backend_delivery.backend_worker_repository_arn
}

output "codebuild_project_name" {
  value = module.backend_delivery.codebuild_project_name
}

output "deploy_codebuild_project_name" {
  value = module.backend_delivery.deploy_codebuild_project_name
}

output "codepipeline_names" {
  value = module.backend_delivery.codepipeline_names
}

output "dev_codepipeline_name" {
  value = try(module.backend_delivery.codepipeline_names.dev, null)
}

output "prod_codepipeline_name" {
  value = try(module.backend_delivery.codepipeline_names.prod, null)
}

output "github_connection_arn" {
  value = module.backend_delivery.github_connection_arn
}

output "github_connection_status" {
  value = module.backend_delivery.github_connection_status
}
