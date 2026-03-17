REGION ?= us-east-1
YEAR   ?= 2024
MONTH  ?= 09

# Read Terraform outputs (requires apply to have run)
STATE_MACHINE  = $(shell cd terraform && terraform output -raw state_machine_arn 2>/dev/null)
WG_NAME        = $(shell cd terraform && terraform output -raw redshift_workgroup_name 2>/dev/null)

.PHONY: init plan apply destroy run-pipeline status logs-glue verify

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply -auto-approve

destroy:
	cd terraform && terraform destroy -auto-approve

## Start a pipeline execution for a given month.
## Usage: make run-pipeline YEAR=2024 MONTH=03
run-pipeline:
	@echo "Starting pipeline for $(YEAR)-$(MONTH)..."
	aws stepfunctions start-execution \
		--state-machine-arn $(STATE_MACHINE) \
		--input '{"year":"$(YEAR)","month":"$(MONTH)"}' \
		--region $(REGION)

## Tail the most recent execution status
status:
	aws stepfunctions list-executions \
		--state-machine-arn $(STATE_MACHINE) \
		--max-results 5 \
		--region $(REGION)

## Follow Glue job output logs (all jobs)
logs-glue:
	aws logs tail /aws-glue/jobs/output --follow --region $(REGION)

## Query Redshift to confirm rows loaded
verify:
	aws redshift-data execute-statement \
		--workgroup-name $(WG_NAME) \
		--database tlc \
		--sql "SELECT COUNT(*), DATE_TRUNC('month', pickup_datetime) AS month FROM yellow_trips GROUP BY 2 ORDER BY 2 DESC LIMIT 10;" \
		--region $(REGION)
