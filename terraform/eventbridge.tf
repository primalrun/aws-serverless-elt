# Runs on the 5th of each month at 06:00 UTC.
# Invokes the trigger Lambda, which computes the latest available TLC month
# (current month - 2) and starts a Step Functions execution automatically.
# For ad-hoc runs use: make run-pipeline YEAR=2024 MONTH=09

resource "aws_scheduler_schedule" "monthly" {
  name  = "${var.project}-monthly"
  state = "DISABLED" # Enable once ready for production use

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 6 5 * ? *)"

  target {
    arn      = aws_lambda_function.trigger.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = "{}"
  }
}
