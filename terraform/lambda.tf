data "archive_file" "trigger" {
  type        = "zip"
  source_file = "${path.module}/../lambda/trigger.py"
  output_path = "${path.module}/../lambda/trigger.zip"
}

resource "aws_lambda_function" "trigger" {
  function_name    = "${var.project}-trigger"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "trigger.handler"
  filename         = data.archive_file.trigger.output_path
  source_code_hash = data.archive_file.trigger.output_base64sha256

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.pipeline.arn
    }
  }

  tags = { Project = var.project }
}

resource "aws_iam_role" "lambda" {
  name = "${var.project}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_sfn" {
  name = "${var.project}-lambda-sfn"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.pipeline.arn
    }]
  })
}

# Allow EventBridge Scheduler to invoke the Lambda
resource "aws_lambda_permission" "scheduler" {
  statement_id  = "AllowScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.monthly.arn
}
