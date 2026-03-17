resource "aws_redshiftserverless_namespace" "main" {
  namespace_name      = "${var.project}-namespace"
  db_name             = "tlc"
  admin_username      = var.redshift_admin_user
  admin_user_password = var.redshift_admin_password
  iam_roles           = [aws_iam_role.redshift_s3.arn]

  tags = { Project = var.project }
}

resource "aws_redshiftserverless_workgroup" "main" {
  namespace_name      = aws_redshiftserverless_namespace.main.namespace_name
  workgroup_name      = "${var.project}-workgroup"
  base_capacity       = 8 # Minimum RPU — free tier eligible
  publicly_accessible = false

  tags = { Project = var.project }
}
