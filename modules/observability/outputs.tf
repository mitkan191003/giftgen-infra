output "alb_access_logs_bucket_name" {
  value = aws_s3_bucket.alb_access_logs.bucket
}

output "alb_access_logs_prefix" {
  value = local.alb_access_logs_prefix
}

output "alert_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}

output "container_insights_log_group_names" {
  value = values(aws_cloudwatch_log_group.container_insights)[*].name
}

output "api_canary_name" {
  value = local.create_api_canary ? aws_synthetics_canary.api_health[0].name : null
}
