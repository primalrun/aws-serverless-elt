# Internals

## Files Used When the Pipeline Runs

### `make apply` — infrastructure provisioning only
- `terraform/` — all `.tf` files provisioned once; not touched at runtime
- `glue/jobs/*.py` — uploaded to S3 by Terraform at apply time via `aws_s3_object`

### `make run-pipeline` — starts an execution
- `terraform/outputs.tf` — reads `state_machine_arn` to build the CLI command

### During a Step Functions execution
- `glue/jobs/ingest_raw.py` — runs in Glue Python Shell, reads from CloudFront, writes to S3 raw
- `glue/jobs/transform_trips.py` — runs in Glue Spark, reads S3 raw, writes S3 processed
- `glue/jobs/load_redshift.py` — runs in Glue Python Shell, COPYs S3 processed → Redshift

### Never used at runtime
- `sql/create_tables.sql` — reference DDL only; the load job handles `CREATE TABLE IF NOT EXISTS`
- `terraform/` — infrastructure is already provisioned before the pipeline runs
- `.env.example`, `terraform.tfvars.example` — reference only
- `README.md`, `docs/` — repo docs only

---

## Step Functions `.sync` Integration

Each state in the workflow uses `arn:aws:states:::glue:startJobRun.sync` as its resource. The `.sync` suffix is an AWS SDK optimized integration — it starts the Glue job and then polls the job status in the background until the job reaches a terminal state (SUCCEEDED, FAILED, STOPPED) before advancing to the next state.

Without `.sync`, you would need to build the polling loop yourself:
1. Start the Glue job (`startJobRun`)
2. Wait a fixed interval (`Wait` state)
3. Check job status (`GetJobRun`)
4. Loop back to Wait if still running
5. Branch on SUCCEEDED vs FAILED

The `.sync` integration collapses all of that into a single `Task` state. Step Functions handles the polling internally at no extra cost.

---

## Glue Python Shell vs Glue Spark

This project uses both Glue job types for different purposes:

| Job | Type | DPU | Why |
|---|---|---|---|
| `ingest_raw` | Python Shell | 0.0625 (1/16) | Pure I/O — downloads a file and uploads it to S3. No data processing. |
| `transform_trips` | Spark (G.1X) | 2 workers | Reads millions of rows, filters, renames columns, rewrites parquet. Needs distributed processing. |
| `load_redshift` | Python Shell | 0.0625 (1/16) | Submits a SQL statement to the Redshift Data API. No data passes through the job. |

Python Shell jobs are billed at 1/16 DPU — about 1 cent for a job that runs under a minute. Spark jobs are billed by the number of workers and runtime, making them more expensive but necessary for large-scale data processing.

---

## Redshift Data API

The `load_redshift` job connects to Redshift Serverless using the **Redshift Data API** (`boto3` client `redshift-data`) rather than a direct JDBC/ODBC connection.

The traditional approach requires:
- A JDBC driver
- Network connectivity (VPC, security groups, subnet routing)
- Database credentials passed as connection parameters

The Redshift Data API approach requires:
- An IAM permission (`redshift-data:ExecuteStatement`)
- IAM authentication against the workgroup (`redshift-serverless:GetCredentials`)

No VPC configuration, no JDBC driver, no password in the job. The Glue role's IAM identity is used to authenticate automatically.

The API is asynchronous — `execute_statement` submits the SQL and returns a statement ID immediately. The job then polls `describe_statement` until the status is `FINISHED` or `FAILED`.

---

## COPY Command

The `COPY` command is Redshift's bulk-load mechanism. It reads files directly from S3 into a Redshift table — Redshift's compute nodes fetch the data in parallel, making it far faster than row-by-row `INSERT`.

```sql
COPY yellow_trips
FROM 's3://tlc-serverless-processed-.../yellow/2024/09/'
IAM_ROLE 'arn:aws:iam::...:role/tlc-serverless-redshift-s3-role'
FORMAT AS PARQUET;
```

- **`FROM`** — an S3 prefix, not a single file. Redshift loads all objects under that prefix.
- **`IAM_ROLE`** — the role Redshift assumes to read from S3. This is a separate role from the Glue role. Redshift calls S3 directly; the data never passes through the Glue job.
- **`FORMAT AS PARQUET`** — tells Redshift to read the files as parquet. Column names and types are inferred from the parquet schema and matched to the table definition.

---

## Three S3 Buckets

| Bucket | Purpose |
|---|---|
| `tlc-serverless-raw-{account}` | Landing zone — raw parquet files exactly as downloaded from TLC |
| `tlc-serverless-processed-{account}` | Cleaned parquet — filtered rows, renamed columns, ready for COPY |
| `tlc-serverless-scripts-{account}` | Glue job scripts — uploaded by Terraform at apply time |

Separating raw and processed gives a clean reprocessing story: if the transform logic changes, raw data is preserved and `transform_trips` can be re-run without re-downloading from TLC.

---

## Four IAM Roles

| Role | Used by | Why separate |
|---|---|---|
| `tlc-serverless-glue-role` | Glue jobs | Needs S3 read/write + Redshift Data API access |
| `tlc-serverless-redshift-s3-role` | Redshift (during COPY) | Needs S3 read access; passed as `IAM_ROLE` in the COPY command |
| `tlc-serverless-sfn-role` | Step Functions | Needs `glue:StartJobRun` + polling permissions |
| `tlc-serverless-scheduler-role` | EventBridge Scheduler | Needs `states:StartExecution` on the state machine |

Each role has only the permissions it needs. Glue cannot start Step Functions executions. Step Functions cannot read S3 directly. This follows the principle of least privilege.

---

## `--additional-python-modules`

Glue Python Shell jobs run in a managed Python environment with a fixed set of pre-installed packages. The botocore version bundled with Python Shell 3.9 predates the `WorkgroupName` parameter added to the Redshift Data API.

Adding `--additional-python-modules = "boto3>=1.26.0,botocore>=1.29.0"` to the Glue job's default arguments tells Glue to `pip install` the specified packages into the job's environment before running the script. This upgrades boto3/botocore without requiring a custom Docker image or Glue container.

---

## DISTSTYLE AUTO / SORTKEY AUTO

```sql
CREATE TABLE IF NOT EXISTS yellow_trips (...)
DISTSTYLE AUTO
SORTKEY AUTO;
```

Redshift is a columnar MPP (massively parallel processing) database. Rows are distributed across compute nodes according to the distribution style, and sorted within each node according to the sort key. Choosing the wrong settings can cause data skew (one node doing most of the work) or slow query performance.

`DISTSTYLE AUTO` and `SORTKEY AUTO` tell Redshift to analyze the data after loading and automatically choose the optimal distribution and sort keys. This is the recommended default for new tables — Redshift has enough information about the data to make better choices than a developer guessing upfront.

---

## EventBridge Scheduler vs EventBridge Rules

This project uses **EventBridge Scheduler** (`aws_scheduler_schedule`) rather than the older **EventBridge Rules** (`aws_cloudwatch_event_rule`).

Both can trigger Step Functions on a cron schedule, but Scheduler has several advantages:
- Supports time zones natively
- Has a `flexible_time_window` option to avoid thundering-herd problems
- Is purpose-built for scheduling (Rules are primarily for event routing)
- Manages its own IAM role per schedule rather than a shared role

The schedule runs on the 5th of each month. The input (`year`, `month`) is static and should be updated each month to match the latest available TLC data release (typically 2 months behind). For ad-hoc runs, `make run-pipeline YEAR=2024 MONTH=09` bypasses the schedule entirely.
