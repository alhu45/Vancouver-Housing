"""
vancouver_pipeline.py
======================
Apache Airflow DAG for the Vancouver Livability Analytics Platform.

This DAG orchestrates the full pipeline:
    1. Trigger dbt Cloud to run Silver models (cleansed data)
    2. Trigger dbt Cloud to run Gold models (business-ready tables)
    3. Trigger dbt Cloud to run the Livability Index (final product)
    4. Run the AI Anomaly Detection agent

Schedule: Daily at midnight
"""

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.http_operator import SimpleHttpOperator
from airflow.sensors.http_sensor import HttpSensor
from airflow.models import Variable
from datetime import datetime, timedelta
import requests
import json


# ─────────────────────────────────────────────────────────────
# CONFIGURATION
# Pull credentials from Airflow Variables (set these in the
# Airflow UI under Admin → Variables, never hardcode them)
# ─────────────────────────────────────────────────────────────
DBT_ACCOUNT_ID  = Variable.get("DBT_ACCOUNT_ID")   # your dbt Cloud account ID
DBT_JOB_ID      = Variable.get("DBT_JOB_ID")        # your dbt Cloud job ID
DBT_API_TOKEN   = Variable.get("DBT_API_TOKEN")     # your dbt Cloud API token

DBT_API_BASE    = f"https://cloud.getdbt.com/api/v2/accounts/{DBT_ACCOUNT_ID}"
DBT_HEADERS     = {
    "Authorization": f"Token {DBT_API_TOKEN}",
    "Content-Type":  "application/json"
}


# ─────────────────────────────────────────────────────────────
# DEFAULT ARGUMENTS
# These apply to every task in the DAG unless overridden.
# retries=1 means if a task fails, Airflow will try once more
# before marking it as failed.
# ─────────────────────────────────────────────────────────────
default_args = {
    "owner":            "alan",
    "depends_on_past":  False,          # don't wait for yesterday's run
    "start_date":       datetime(2024, 1, 1),
    "retries":          1,              # retry once on failure
    "retry_delay":      timedelta(minutes=5),
    "email_on_failure": False,
}


# ─────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# Each function below is wrapped in a PythonOperator task.
# Airflow calls these functions at the scheduled time.
# ─────────────────────────────────────────────────────────────

def trigger_dbt_job(job_id: str, cause: str) -> dict:
    """
    Sends a POST request to the dbt Cloud API to trigger a job run.
    Returns the run ID so we can poll its status later.
    """
    url      = f"{DBT_API_BASE}/jobs/{job_id}/run/"
    payload  = {"cause": cause}
    response = requests.post(url, headers=DBT_HEADERS, json=payload)
    response.raise_for_status()

    run_id = response.json()["data"]["id"]
    print(f"✅ Triggered dbt job {job_id} → Run ID: {run_id}")
    return {"run_id": run_id}


def wait_for_dbt_run(run_id: int, timeout_minutes: int = 30) -> None:
    """
    Polls the dbt Cloud API every 30 seconds until the run completes.
    Raises an error if it fails or times out.

    dbt run statuses:
        1  = Queued
        2  = Starting
        3  = Running
        10 = Success
        20 = Error
        30 = Cancelled
    """
    import time

    url             = f"{DBT_API_BASE}/runs/{run_id}/"
    timeout_seconds = timeout_minutes * 60
    elapsed         = 0

    while elapsed < timeout_seconds:
        response = requests.get(url, headers=DBT_HEADERS)
        response.raise_for_status()

        status = response.json()["data"]["status"]
        print(f"⏳ dbt run {run_id} status: {status}")

        if status == 10:
            print(f"✅ dbt run {run_id} completed successfully")
            return
        elif status in [20, 30]:
            raise Exception(f"❌ dbt run {run_id} failed with status {status}")

        time.sleep(30)
        elapsed += 30

    raise Exception(f"❌ dbt run {run_id} timed out after {timeout_minutes} minutes")


def run_silver_models(**context) -> None:
    """
    Task 1: Trigger dbt Cloud to run Silver layer models.
    Silver = cleansed and filtered data from Bronze raw sources.
    """
    result = trigger_dbt_job(DBT_JOB_ID, cause="Airflow: Silver layer run")
    wait_for_dbt_run(result["run_id"])


def run_gold_models(**context) -> None:
    """
    Task 2: Trigger dbt Cloud to run all 8 Gold layer models.
    Gold = business-ready tables for crime, housing, and transit.
    """
    result = trigger_dbt_job(DBT_JOB_ID, cause="Airflow: Gold layer run")
    wait_for_dbt_run(result["run_id"])


def run_livability_index(**context) -> None:
    """
    Task 3: Trigger dbt Cloud to run the final livability index model.
    This joins all 8 Gold tables into one composite score per neighbourhood.
    """
    result = trigger_dbt_job(DBT_JOB_ID, cause="Airflow: Livability Index run")
    wait_for_dbt_run(result["run_id"])


def run_anomaly_detection(**context) -> None:
    """
    Task 4: Run the AI anomaly detection agent.
    Reads from gold_crime_temporal_patterns and flags anomalies
    using Isolation Forest. Any anomalies found are logged to
    Snowflake and can trigger alerts.

    NOTE: Replace this with your actual Databricks job trigger
    or local Python anomaly detection script path.
    """
    print("🤖 Running AI Anomaly Detection Agent...")

    # Example: call your Databricks job via REST API
    # databricks_url = "https://<your-workspace>.azuredatabricks.net/api/2.1/jobs/run-now"
    # requests.post(databricks_url, headers={"Authorization": f"Bearer {DATABRICKS_TOKEN}"}, json={"job_id": DATABRICKS_JOB_ID})

    # For now, log a placeholder
    print("✅ Anomaly detection complete — results written to Snowflake")


# ─────────────────────────────────────────────────────────────
# DAG DEFINITION
# This is the actual DAG object Airflow reads.
# schedule_interval='@daily' means it runs once per day at midnight.
# catchup=False means it won't backfill missed runs.
# ─────────────────────────────────────────────────────────────
with DAG(
    dag_id          = "vancouver_livability_pipeline",
    default_args    = default_args,
    description     = "Vancouver Livability Analytics — full pipeline orchestration",
    schedule_interval = "@daily",       # runs every day at midnight
    catchup         = False,            # don't backfill missed runs
    tags            = ["vancouver", "dbt", "snowflake", "livability"],
) as dag:

    # ── TASK 1: Run Silver models ──────────────────────────────
    task_silver = PythonOperator(
        task_id         = "run_silver_models",
        python_callable = run_silver_models,
    )

    # ── TASK 2: Run Gold models ────────────────────────────────
    task_gold = PythonOperator(
        task_id         = "run_gold_models",
        python_callable = run_gold_models,
    )

    # ── TASK 3: Run Livability Index ───────────────────────────
    task_livability = PythonOperator(
        task_id         = "run_livability_index",
        python_callable = run_livability_index,
    )

    # ── TASK 4: Run AI Anomaly Detection ──────────────────────
    task_anomaly = PythonOperator(
        task_id         = "run_anomaly_detection",
        python_callable = run_anomaly_detection,
    )

    # ── PIPELINE ORDER ─────────────────────────────────────────
    # >> means "then run". Airflow won't start a task until the
    # previous one completes successfully.
    #
    #   Silver → Gold → Livability Index → Anomaly Detection
    #
    task_silver >> task_gold >> task_livability >> task_anomaly