# SNOWFLAKE ACCOUNT
# │
# ├── USERS & ROLES
# │
# ├── WAREHOUSES (COMPUTE)
# │    └── VANCOUVER_WH
# │
# └── DATA
#      └── DATABASE: VANCOUVER_DATA
#           ├── SCHEMA: BRONZE
#           │    ├── TABLES
#           │    └── STAGES → S3
#           ├── SCHEMA: SILVER
#           └── SCHEMA: GOLD

# The 4 variables you need to connect to Snowflake account
variable "snowflake_organization" {
  type = string
}

variable "snowflake_account_name" {
  type = string
}

variable "snowflake_user" {
    type = string
}

variable "snowflake_password" {
    type      = string
    sensitive = true
}

variable "snowflake_private_key_path" { type = string }

# Parts and Variables of Snowlfake
# Database Configs
variable "database_name" {
    description = "Name of the main Snowflake database"
    type = string
    default = "VANCOUVER_DATA"
}

# Warehouse Configs (The engines that run your queries)
variable "warehouse_name" {
    description = "Name of Snowflake Warehouse"
    type = string
    default = "VANCOUVER_WH"
}

variable "warehouse_size" {
    description = "Size of Snowflake warehouse"
    type        = string
    default     = "X-SMALL"
  
  # OPTIONS: X-SMALL, SMALL, MEDIUM, LARGE, X-LARGE, 2X-LARGE, etc.
  # COST: X-SMALL = $2/hour when running (cheapest)
  # WHY X-SMALL: Perfect for development and small datasets
  # WHEN TO UPGRADE: If queries take >5 minutes, try SMALL
}

#AWS S3 Bucket Integration that links Snowflake and AWS
variable "s3_bronze_bucket" {
    description = "Name of S3 bronze bucket (from AWS Terraform output)"
    type        = string
  
  # WHERE TO GET: Run 'terraform output bronze_bucket_name' in aws/ folder
  # EXAMPLE: "vancouver-data-bronze-dev"
}

variable "s3_silver_bucket" {
    description = "Name of S3 silver bucket (from AWS Terraform output)"
    type        = string
  
  # EXAMPLE: "vancouver-data-silver-dev"
}

variable "s3_gold_bucket" {
    description = "Name of S3 gold bucket (from AWS Terraform output)"
    type        = string
  
  # EXAMPLE: "vancouver-data-gold-dev"
}

variable "aws_iam_role_arn" {
    description = "ARN of AWS IAM role that Snowflake will assume"
    type        = string
  
  # WHERE TO GET: Run 'terraform output snowflake_role_arn' in aws/ folder
  # EXAMPLE: "arn:aws:iam::123456789012:role/vancouver-data-snowflake-role"
  # WHY: This is how Snowflake gets permission to read your S3 data
}

# ==========================================
# AWS REGION (needed for S3 paths)
# ==========================================

variable "aws_region" {
    description = "AWS region where S3 buckets are located"
    type        = string
    default     = "ca-central-1"
  
  # MUST MATCH: The region you used in AWS Terraform
}

# ==========================================
# HOW TO USE THESE VARIABLES:
# ==========================================
# Create a file called terraform.tfvars:
#
# snowflake_account  = "xy12345.us-east-1"
# snowflake_user     = "your.email@gmail.com"
# snowflake_password = "YourPassword123"
# s3_bronze_bucket   = "vancouver-data-bronze-dev"
# s3_silver_bucket   = "vancouver-data-silver-dev"
# s3_gold_bucket     = "vancouver-data-gold-dev"
# aws_iam_role_arn   = "arn:aws:iam::123456:role/vancouver-data-snowflake-role"
#
# IMPORTANT: Add terraform.tfvars to .gitignore!
# ==========================================
