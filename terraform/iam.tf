# ── Glue service role ────────────────────────────────────────────────────────

resource "aws_iam_role" "glue" {
  name = "${var.project}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3" {
  name = "${var.project}-glue-s3"
  role = aws_iam_role.glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.raw.arn, "${aws_s3_bucket.raw.arn}/*",
        aws_s3_bucket.processed.arn, "${aws_s3_bucket.processed.arn}/*",
        aws_s3_bucket.scripts.arn, "${aws_s3_bucket.scripts.arn}/*",
      ]
    }]
  })
}

resource "aws_iam_role_policy" "glue_redshift_data" {
  name = "${var.project}-glue-redshift-data"
  role = aws_iam_role.glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "redshift-data:ExecuteStatement",
        "redshift-data:GetStatementResult",
        "redshift-data:DescribeStatement",
        "redshift-serverless:GetWorkgroup",
        "redshift-serverless:GetCredentials",
      ]
      Resource = "*"
    }]
  })
}

# ── Redshift S3 access role (passed as IAM_ROLE in COPY command) ─────────────

resource "aws_iam_role" "redshift_s3" {
  name = "${var.project}-redshift-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "redshift.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "redshift_s3_read" {
  name = "${var.project}-redshift-s3-read"
  role = aws_iam_role.redshift_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.processed.arn, "${aws_s3_bucket.processed.arn}/*"]
    }]
  })
}

# ── Step Functions role ───────────────────────────────────────────────────────

resource "aws_iam_role" "stepfunctions" {
  name = "${var.project}-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "sfn_glue" {
  name = "${var.project}-sfn-glue"
  role = aws_iam_role.stepfunctions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "glue:StartJobRun",
        "glue:GetJobRun",
        "glue:GetJobRuns",
        "glue:BatchStopJobRun",
      ]
      Resource = "*"
    }]
  })
}

# ── EventBridge Scheduler role ────────────────────────────────────────────────

resource "aws_iam_role" "scheduler" {
  name = "${var.project}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_lambda" {
  name = "${var.project}-scheduler-lambda"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.trigger.arn
    }]
  })
}
