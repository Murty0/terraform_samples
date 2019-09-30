resource "aws_cloudwatch_log_metric_filter" "app_already_running" {
  name           = "AppAlreadyRunningError"
  pattern        = "App already running"
  log_group_name = "/aws/lambda/vendors_admin_app"

  metric_transformation {
    name      = "AppAlreadyRunningError"
    namespace = "StreamAlert"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "task_timed_out" {
  name           = "TaskTimedOutError"
  pattern        = "Task timed out"
  log_group_name = "/aws/lambda/vendors_admin_app"

  metric_transformation {
    name      = "TaskTimedOutError"
    namespace = "StreamAlert"
    value     = "1"
  }
}
