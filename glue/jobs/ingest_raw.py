"""
Glue Python Shell job — ingest_raw

Downloads a single month of NYC TLC yellow-taxi parquet from the public
CloudFront distribution and uploads it to the raw S3 bucket.

Arguments (passed by Step Functions):
  --year        4-digit year, e.g. "2024"
  --month       2-digit month, e.g. "03"
  --raw_bucket  Destination S3 bucket (injected as default_argument in Glue)
"""

import sys
import urllib.request
import boto3
from awsglue.utils import getResolvedOptions

args = getResolvedOptions(sys.argv, ["year", "month", "raw_bucket"])
year = args["year"]
month = args["month"].zfill(2)
bucket = args["raw_bucket"]

filename = f"yellow_tripdata_{year}-{month}.parquet"
url = f"https://d37ci6vzurychx.cloudfront.net/trip-data/{filename}"
local_path = f"/tmp/{filename}"
s3_key = f"yellow/{year}/{month}/{filename}"

print(f"Downloading {url}")
urllib.request.urlretrieve(url, local_path)
print(f"Download complete — uploading to s3://{bucket}/{s3_key}")

s3 = boto3.client("s3")
s3.upload_file(local_path, bucket, s3_key)
print(f"Upload complete: s3://{bucket}/{s3_key}")
