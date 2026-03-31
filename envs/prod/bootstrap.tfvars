region            = "us-east-1"
project           = "giftgen"
environment       = "prod"
state_bucket_name = "giftgen-terraform-state"
core_state_key    = "environments/prod/terraform.tfstate"

application_repo_url        = "https://github.com/mitkan191003/giftgen-backend.git"
application_target_revision = "main"
application_chart_path      = "helm/giftgen"
application_value_file      = "values-prod.yaml"
application_auto_sync       = false
cleanup_schedule            = "0 */6 * * *"

metric_namespace                  = "GiftGen/Application"
backend_log_level                 = "INFO"
backend_request_id_header_name    = "X-Request-Id"
backend_sentry_dsn                = ""
backend_sentry_traces_sample_rate = 0.1
alert_email                       = ""
observability_log_retention_days  = 30
alb_access_logs_retention_days    = 30
canary_artifacts_retention_days   = 14
enable_api_canary                 = true
api_canary_schedule_expression    = "rate(5 minutes)"
