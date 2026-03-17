data "aws_caller_identity" "current" {}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  raw_bucket       = "${var.project}-raw-${local.account_id}"
  processed_bucket = "${var.project}-processed-${local.account_id}"
  scripts_bucket   = "${var.project}-scripts-${local.account_id}"
}

resource "aws_s3_bucket" "raw" {
  bucket        = local.raw_bucket
  force_destroy = true
  tags          = { Project = var.project }
}

resource "aws_s3_bucket" "processed" {
  bucket        = local.processed_bucket
  force_destroy = true
  tags          = { Project = var.project }
}

resource "aws_s3_bucket" "scripts" {
  bucket        = local.scripts_bucket
  force_destroy = true
  tags          = { Project = var.project }
}
