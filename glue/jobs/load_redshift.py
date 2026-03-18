"""
Glue Python Shell job — load_redshift

Creates the yellow_trips table in Redshift Serverless (if it doesn't exist),
deletes any existing rows for the target month, then COPYs the processed
parquet from S3. The delete-before-copy pattern makes the job idempotent —
re-running the same month any number of times produces the correct result.

Uses the Redshift Data API (no direct JDBC connection needed).

Arguments (passed by Step Functions):
  --year              4-digit year, e.g. "2024"
  --month             2-digit month, e.g. "03"
  --processed_bucket  S3 bucket holding processed parquet
  --workgroup         Redshift Serverless workgroup name
  --database          Redshift database name (e.g. "tlc")
  --iam_role          IAM role ARN that Redshift uses to read from S3
"""

import sys
import time
import boto3
from awsglue.utils import getResolvedOptions

args = getResolvedOptions(
    sys.argv,
    ["year", "month", "processed_bucket", "workgroup", "database", "iam_role"],
)

year = args["year"]
month = args["month"].zfill(2)
bucket = args["processed_bucket"]
workgroup = args["workgroup"]
database = args["database"]
iam_role = args["iam_role"]

client = boto3.client("redshift-data")


def run_sql(sql: str) -> None:
    """Submit a SQL statement and block until it finishes."""
    resp = client.execute_statement(
        WorkgroupName=workgroup,
        Database=database,
        Sql=sql,
    )
    statement_id = resp["Id"]

    while True:
        status = client.describe_statement(Id=statement_id)
        state = status["Status"]
        if state == "FINISHED":
            return
        if state in ("FAILED", "ABORTED"):
            raise RuntimeError(f"SQL failed [{state}]: {status.get('Error', '')}")
        time.sleep(5)


# Create table on first run
create_table_sql = """
CREATE TABLE IF NOT EXISTS yellow_trips (
    vendor_id           INTEGER,
    pickup_datetime     TIMESTAMP,
    dropoff_datetime    TIMESTAMP,
    passenger_count     INTEGER,
    trip_distance       DOUBLE PRECISION,
    pickup_location_id  INTEGER,
    dropoff_location_id INTEGER,
    payment_type        INTEGER,
    fare_amount         DOUBLE PRECISION,
    tip_amount          DOUBLE PRECISION,
    total_amount        DOUBLE PRECISION
)
DISTSTYLE AUTO
SORTKEY AUTO;
"""

print("Ensuring yellow_trips table exists")
run_sql(create_table_sql)

s3_path = f"s3://{bucket}/yellow/{year}/{month}/"
copy_sql = f"""
COPY yellow_trips
FROM '{s3_path}'
IAM_ROLE '{iam_role}'
FORMAT AS PARQUET;
"""

delete_sql = f"""
DELETE FROM yellow_trips
WHERE DATE_TRUNC('month', pickup_datetime) = '{year}-{month}-01';
"""

print(f"Deleting existing rows for {year}-{month} (idempotent)")
run_sql(delete_sql)

print(f"Running COPY from {s3_path}")
run_sql(copy_sql)
print(f"Load complete for {year}-{month}")
