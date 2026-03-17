resource "aws_sfn_state_machine" "pipeline" {
  name     = "${var.project}-pipeline"
  role_arn = aws_iam_role.stepfunctions.arn

  definition = jsonencode({
    Comment = "TLC Serverless ELT: ingest raw → transform → load Redshift"
    StartAt = "IngestRaw"
    States = {
      IngestRaw = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = aws_glue_job.ingest_raw.name
          Arguments = {
            "--year.$"  = "$.year"
            "--month.$" = "$.month"
          }
        }
        ResultPath = "$.ingest_result"
        Next       = "TransformTrips"
      }

      TransformTrips = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = aws_glue_job.transform_trips.name
          Arguments = {
            "--year.$"  = "$.year"
            "--month.$" = "$.month"
          }
        }
        ResultPath = "$.transform_result"
        Next       = "LoadRedshift"
      }

      LoadRedshift = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = aws_glue_job.load_redshift.name
          Arguments = {
            "--year.$"  = "$.year"
            "--month.$" = "$.month"
          }
        }
        ResultPath = "$.load_result"
        Next       = "PipelineSucceeded"
      }

      PipelineSucceeded = {
        Type = "Succeed"
      }
    }
  })

  tags = { Project = var.project }
}
