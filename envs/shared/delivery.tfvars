region      = "us-east-1"
project     = "giftgen"
environment = "shared"

# Leave empty to let the module derive names from project/environment, or set a
# stable prefix like "giftgen" to keep shared delivery resources environment-agnostic.
name_prefix          = "giftgen"
repository_namespace = "giftgen"

github_repository_full_name = "mitkan191003/giftgen-backend"
github_connection_name      = "giftgen-backend"

ecr_retention_count = 3
log_retention_days  = 1

pipelines = {
  dev = {
    branch                    = "dev"
    argocd_server             = "https://argocd-dev.giftgen.mithrak.com"
    argocd_application_name   = "giftgen"
    argocd_deploy_secret_name = "giftgen-dev/argocd-deploy"
  }
  prod = {
    branch                    = "main"
    argocd_server             = "https://argocd.giftgen.mithrak.com"
    argocd_application_name   = "giftgen"
    argocd_deploy_secret_name = "giftgen-prod/argocd-deploy"
  }
}
