# ==========================================
# HOW TO USE THESE OUTPUTS:
# ==========================================
# After running 'terraform apply', you'll see something like:
#
# Outputs:
# bronze_bucket_name = "vancouver-data-bronze-dev"
# silver_bucket_name = "vancouver-data-silver-dev"
# databricks_role_arn = "arn:aws:iam::123456:role/vancouver-data-databricks-role"
#
# TO GET SPECIFIC OUTPUT:
# terraform output bronze_bucket_name
#
# TO GET SENSITIVE OUTPUT:
# terraform output airflow_secret_access_key
#
# TO USE IN ANOTHER TERRAFORM MODULE:
# data.terraform_remote_state.aws.outputs.bronze_bucket_name
# ==========================================

output "bronze_bucket_name" {
  description = "Name of the Bronze S3 bucket"
  value       = aws_s3_bucket.bronze.id
  
  # DISPLAYS: "vancouver-data-bronze-dev"
  # USE IN: Your Airflow DAGs to upload files
  # EXAMPLE: s3.upload('crime.csv', 'vancouver-data-bronze-dev/crime/raw/')
}

output "silver_bucket_name" {
  description = "Name of the Silver S3 bucket"
  value       = aws_s3_bucket.silver.id
  
  # USE IN: Databricks notebooks to write cleaned data
}

output "gold_bucket_name" {
  description = "Name of the Gold S3 bucket"
  value       = aws_s3_bucket.gold.id
  
  # USE IN: Final analytics output destination
}

# ==========================================
# S3 BUCKET ARNs (for IAM policies and permissions)
# ==========================================

output "bronze_bucket_arn" {
  description = "ARN of the Bronze S3 bucket"
  value       = aws_s3_bucket.bronze.arn
  
  # DISPLAYS: "arn:aws:s3:::vancouver-data-bronze-dev"
  # WHY ARN: Amazon Resource Name - unique ID for this bucket
  # USE IN: Setting up permissions for other services
}

output "silver_bucket_arn" {
  description = "ARN of the Silver S3 bucket"
  value       = aws_s3_bucket.silver.arn
}

output "gold_bucket_arn" {
  description = "ARN of the Gold S3 bucket"
  value       = aws_s3_bucket.gold.arn
}

# ==========================================
# IAM ROLE ARNs (for Databricks and Snowflake setup)
# ==========================================

output "databricks_role_arn" {
  description = "ARN of IAM role for Databricks to access S3"
  value       = aws_iam_role.databricks_s3_access.arn
  
  # DISPLAYS: "arn:aws:iam::123456789012:role/vancouver-data-databricks-role"
  # USE IN: Copy this into Databricks when setting up S3 connection
  # RESULT: Databricks can read/write your S3 buckets
}

# Comment out for now
output "snowflake_role_arn" {
  description = "ARN of IAM role for Snowflake to access S3"
  value       = aws_iam_role.snowflake_s3_access.arn
  
  # DISPLAYS: "arn:aws:iam::123456789012:role/vancouver-data-snowflake-role"
  # USE IN: Copy this into Snowflake storage integration setup
  # RESULT: Snowflake can read your S3 data
}

# ==========================================
# AIRFLOW CREDENTIALS (for API access)
# ==========================================

output "airflow_access_key_id" {
  description = "Access key ID for Airflow IAM user"
  value       = aws_iam_access_key.airflow.id
  sensitive   = true  # Won't display in terminal by default
  
  # DISPLAYS: "AKIAIOSFODNN7EXAMPLE"
  # USE IN: Airflow connections / environment variables
  # TO SEE: Run 'terraform output airflow_access_key_id'
}

output "airflow_secret_access_key" {
  description = "Secret access key for Airflow IAM user"
  value       = aws_iam_access_key.airflow.secret
  sensitive   = true  # IMPORTANT: Never commit this to git!
  
  # DISPLAYS: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  # USE IN: Airflow to authenticate to AWS
  # TO SEE: Run 'terraform output airflow_secret_access_key'
  # SECURITY: Store in environment variables or secrets manager
}

# ==========================================
# AWS REGION (reminder of where resources are)
# ==========================================

output "aws_region" {
  description = "AWS region where resources were created"
  value       = var.aws_region
  
  # DISPLAYS: "ca-central-1"
  # WHY: Good to know for debugging and configuration
}
