resource "aws_cloudwatch_metric_alarm" "app_already_running_error" {
  alarm_name          = "app-already-running-error"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "AppAlreadyRunningError"
  namespace           = "StreamAlert"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This alarm is triggered when AppAlreadyRunningErrors >= 1"
  alarm_actions       = ["arn:aws:sns:us-east-1:1234456789:streamalert_error_alarm"]

  tags = {
    terraform = true
  }
}

resource "aws_cloudwatch_metric_alarm" "task_timed_out_error" {
  alarm_name          = "task-timed-out-error"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "TaskTimedOutError"
  namespace           = "StreamAlert"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This alarm is triggered when TaskTimedOutErrors >= 1"
  alarm_actions       = ["arn:aws:sns:us-east-1:1234456789:streamalert_error_alarm"]

  tags = {
    terraform = true
  }
}
