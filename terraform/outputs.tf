output "raw_bucket" {
  value = aws_s3_bucket.raw.bucket
}

output "processed_bucket" {
  value = aws_s3_bucket.processed.bucket
}

output "scripts_bucket" {
  value = aws_s3_bucket.scripts.bucket
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.pipeline.arn
}

output "redshift_workgroup_name" {
  value = aws_redshiftserverless_workgroup.main.workgroup_name
}

output "redshift_endpoint" {
  value = aws_redshiftserverless_workgroup.main.endpoint
}

output "glue_role_arn" {
  value = aws_iam_role.glue.arn
}
