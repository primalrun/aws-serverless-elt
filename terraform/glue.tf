# Upload job scripts to S3 at apply time
resource "aws_s3_object" "ingest_raw" {
  bucket = aws_s3_bucket.scripts.bucket
  key    = "jobs/ingest_raw.py"
  source = "${path.module}/../glue/jobs/ingest_raw.py"
  etag   = filemd5("${path.module}/../glue/jobs/ingest_raw.py")
}

resource "aws_s3_object" "transform_trips" {
  bucket = aws_s3_bucket.scripts.bucket
  key    = "jobs/transform_trips.py"
  source = "${path.module}/../glue/jobs/transform_trips.py"
  etag   = filemd5("${path.module}/../glue/jobs/transform_trips.py")
}

resource "aws_s3_object" "load_redshift" {
  bucket = aws_s3_bucket.scripts.bucket
  key    = "jobs/load_redshift.py"
  source = "${path.module}/../glue/jobs/load_redshift.py"
  etag   = filemd5("${path.module}/../glue/jobs/load_redshift.py")
}

# ── Job 1: ingest_raw — Python Shell, downloads TLC parquet → S3 raw ─────────

resource "aws_glue_job" "ingest_raw" {
  name     = "${var.project}-ingest-raw"
  role_arn = aws_iam_role.glue.arn

  command {
    name            = "pythonshell"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/jobs/ingest_raw.py"
    python_version  = "3.9"
  }

  default_arguments = {
    "--raw_bucket"          = aws_s3_bucket.raw.bucket
    "--enable-job-insights" = "true"
  }

  max_capacity = 0.0625 # 1/16 DPU — minimum for Python Shell

  tags       = { Project = var.project }
  depends_on = [aws_s3_object.ingest_raw]
}

# ── Job 2: transform_trips — Glue Spark, S3 raw → clean → S3 processed ───────

resource "aws_glue_job" "transform_trips" {
  name     = "${var.project}-transform-trips"
  role_arn = aws_iam_role.glue.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/jobs/transform_trips.py"
    python_version  = "3"
  }

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  default_arguments = {
    "--raw_bucket"          = aws_s3_bucket.raw.bucket
    "--processed_bucket"    = aws_s3_bucket.processed.bucket
    "--enable-job-insights" = "true"
  }

  tags       = { Project = var.project }
  depends_on = [aws_s3_object.transform_trips]
}

# ── Job 3: load_redshift — Python Shell, COPY S3 processed → Redshift ────────

resource "aws_glue_job" "load_redshift" {
  name     = "${var.project}-load-redshift"
  role_arn = aws_iam_role.glue.arn

  command {
    name            = "pythonshell"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/jobs/load_redshift.py"
    python_version  = "3.9"
  }

  default_arguments = {
    "--processed_bucket"    = aws_s3_bucket.processed.bucket
    "--workgroup"           = aws_redshiftserverless_workgroup.main.workgroup_name
    "--database"            = "tlc"
    "--iam_role"            = aws_iam_role.redshift_s3.arn
    "--enable-job-insights" = "true"
  }

  max_capacity = 0.0625

  tags       = { Project = var.project }
  depends_on = [aws_s3_object.load_redshift]
}
