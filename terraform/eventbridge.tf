# Runs on the 5th of each month at 06:00 UTC.
# TLC data is released ~2 months behind, so update the input year/month accordingly.
# For ad-hoc runs use: make run-pipeline YEAR=2024 MONTH=03

resource "aws_scheduler_schedule" "monthly" {
  name = "${var.project}-monthly"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 6 5 * ? *)"

  target {
    arn      = aws_sfn_state_machine.pipeline.arn
    role_arn = aws_iam_role.scheduler.arn

    # Static input — edit year/month to match the latest available TLC release
    input = jsonencode({
      year  = "2024"
      month = "09"
    })
  }
}
