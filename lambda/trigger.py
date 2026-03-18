"""
Lambda function — trigger

Invoked monthly by EventBridge Scheduler. Computes the latest available
TLC data month (current month minus 2) and starts a Step Functions execution.

TLC yellow-taxi data is released approximately 2 months behind the current
date, so March 2026 → January 2026 is the target month.
"""

import boto3
import datetime
import json
import os

sfn = boto3.client("stepfunctions")


def handler(event, context):
    # Subtract 2 months from today to get the latest available TLC release
    today = datetime.date.today()
    first_of_this_month = today.replace(day=1)
    first_of_last_month = (first_of_this_month - datetime.timedelta(days=1)).replace(day=1)
    target = (first_of_last_month - datetime.timedelta(days=1)).replace(day=1)

    year = str(target.year)
    month = f"{target.month:02d}"

    print(f"Starting pipeline for {year}-{month}")

    response = sfn.start_execution(
        stateMachineArn=os.environ["STATE_MACHINE_ARN"],
        input=json.dumps({"year": year, "month": month}),
    )

    print(f"Execution started: {response['executionArn']}")
    return {"executionArn": response["executionArn"], "year": year, "month": month}
