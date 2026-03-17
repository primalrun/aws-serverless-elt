"""
Glue Spark job — transform_trips

Reads raw TLC yellow-taxi parquet from S3, selects and renames columns,
drops rows with non-positive distances or fares, and writes clean parquet
to the processed S3 bucket.

Arguments (passed by Step Functions):
  --year              4-digit year, e.g. "2024"
  --month             2-digit month, e.g. "03"
  --raw_bucket        Source S3 bucket
  --processed_bucket  Destination S3 bucket
"""

import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
import pyspark.sql.functions as F

args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "year", "month", "raw_bucket", "processed_bucket"],
)

sc = SparkContext()
glue_ctx = GlueContext(sc)
spark = glue_ctx.spark_session
job = Job(glue_ctx)
job.init(args["JOB_NAME"], args)

year = args["year"]
month = args["month"].zfill(2)
raw_bucket = args["raw_bucket"]
processed_bucket = args["processed_bucket"]

input_path = f"s3://{raw_bucket}/yellow/{year}/{month}/"
output_path = f"s3://{processed_bucket}/yellow/{year}/{month}/"

print(f"Reading raw parquet from {input_path}")
df = spark.read.parquet(input_path)

df = (
    df.select(
        F.col("VendorID").cast("int").alias("vendor_id"),
        F.col("tpep_pickup_datetime").alias("pickup_datetime"),
        F.col("tpep_dropoff_datetime").alias("dropoff_datetime"),
        F.col("passenger_count").cast("int").alias("passenger_count"),
        F.col("trip_distance").cast("double").alias("trip_distance"),
        F.col("PULocationID").cast("int").alias("pickup_location_id"),
        F.col("DOLocationID").cast("int").alias("dropoff_location_id"),
        F.col("payment_type").cast("int").alias("payment_type"),
        F.col("fare_amount").cast("double").alias("fare_amount"),
        F.col("tip_amount").cast("double").alias("tip_amount"),
        F.col("total_amount").cast("double").alias("total_amount"),
    )
    .filter(
        (F.col("trip_distance") > 0)
        & (F.col("fare_amount") > 0)
        & (F.col("total_amount") > 0)
    )
)

row_count = df.count()
print(f"Writing {row_count:,} rows to {output_path}")
df.write.mode("overwrite").parquet(output_path)
print("Transform complete")

job.commit()
