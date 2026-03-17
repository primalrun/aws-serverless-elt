variable "aws_region" {
  description = "AWS region for all resources"
  default     = "us-east-1"
}

variable "project" {
  description = "Project name prefix applied to every resource"
  default     = "tlc-serverless"
}

variable "redshift_admin_user" {
  description = "Redshift Serverless admin username"
  default     = "admin"
}

variable "redshift_admin_password" {
  description = "Redshift Serverless admin password (min 8 chars, mixed case + number)"
  sensitive   = true
}
