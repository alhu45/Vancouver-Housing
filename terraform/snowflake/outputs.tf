# terraform/snowflake/outputs.tf
# ==========================================
# WHAT THIS FILE DOES:
# Displays important information after Snowflake resources are created
# Like a summary sheet of what was built
# ==========================================

# ==========================================
# DATABASE & SCHEMA NAMES
# ==========================================

output "database_name" {
  description = "Name of the Snowflake database"
  value       = snowflake_database.vancouver.name
  
  # DISPLAYS: "VANCOUVER_DATA"
  # USE IN: Databricks connection string
  # EXAMPLE: spark.write.option("dbtable", "VANCOUVER_DATA.ANALYTICS.CRIME")
}

output "raw_schema" {
  description = "RAW schema (for external tables from S3)"
  value       = snowflake_schema.raw.name
  
  # DISPLAYS: "RAW"
  # FULL PATH: VANCOUVER_DATA.RAW
}

output "analytics_schema" {
  description = "ANALYTICS schema (for cleaned data)"
  value       = snowflake_schema.analytics.name
  
  # DISPLAYS: "ANALYTICS"
  # FULL PATH: VANCOUVER_DATA.ANALYTICS
}

output "marts_schema" {
  description = "MARTS schema (for business-ready data)"
  value       = snowflake_schema.marts.name
  
  # DISPLAYS: "MARTS"
  # FULL PATH: VANCOUVER_DATA.MARTS
}

# ==========================================
# WAREHOUSE INFORMATION
# ==========================================

output "warehouse_name" {
  description = "Name of the compute warehouse"
  value       = snowflake_warehouse.compute.name
  
  # DISPLAYS: "VANCOUVER_WH"
  # USE IN: SQL queries and Databricks connections
  # EXAMPLE: USE WAREHOUSE VANCOUVER_WH;
}

output "warehouse_size" {
  description = "Size of the warehouse"
  value       = snowflake_warehouse.compute.warehouse_size
  
  # DISPLAYS: "X-SMALL"
  # COST: ~$2/hour when running
  # WHY: Good reminder of what you're paying for
}

# ==========================================
# STORAGE INTEGRATION
# ==========================================

output "storage_integration_name" {
  description = "Name of S3 storage integration"
  value       = snowflake_storage_integration.s3.name
  
  # DISPLAYS: "VANCOUVER_S3_INTEGRATION"
  # USE WHEN: Creating external tables or stages
}

output "storage_integration_arn" {
  description = "IAM user ARN that Snowflake created (paste into AWS trust policy)"
  value       = snowflake_storage_integration.s3.storage_aws_iam_user_arn
  
  # DISPLAYS: "arn:aws:iam::123456789:user/abc123-s-abcd1234"
  # ⚠️ IMPORTANT: Copy this value!
  # YOU NEED TO: Update your AWS IAM role trust policy with this ARN
  #
  # STEPS:
  # 1. Copy this ARN
  # 2. Go to AWS Console → IAM → Roles → vancouver-data-snowflake-role
  # 3. Edit trust policy
  # 4. Replace placeholder ARN with this value
  # 5. Save
  # 
  # WHY: This completes the trust relationship between AWS and Snowflake
}

output "storage_integration_external_id" {
  description = "External ID for Snowflake storage integration"
  value       = snowflake_storage_integration.s3.storage_aws_external_id
  
  # DISPLAYS: "ABC12345_SFCRole=1_ABCDEFGHIJK="
  # USE IN: AWS IAM role trust policy (if needed)
}

# ==========================================
# STAGE NAMES (For querying S3 data)
# ==========================================

output "crime_stage_name" {
  description = "External stage for crime data"
  value       = "${snowflake_database.vancouver.name}.${snowflake_schema.raw.name}.${snowflake_stage.bronze_crime.name}"
  
  # DISPLAYS: "VANCOUVER_DATA.RAW.BRONZE_CRIME_STAGE"
  # USE IN SQL: 
  # LIST @VANCOUVER_DATA.RAW.BRONZE_CRIME_STAGE;
  # SELECT * FROM @VANCOUVER_DATA.RAW.BRONZE_CRIME_STAGE;
}

output "transit_stage_name" {
  description = "External stage for transit data"
  value       = "${snowflake_database.vancouver.name}.${snowflake_schema.raw.name}.${snowflake_stage.bronze_transit.name}"
  
  # DISPLAYS: "VANCOUVER_DATA.RAW.BRONZE_TRANSIT_STAGE"
}

output "housing_stage_name" {
  description = "External stage for housing data"
  value       = "${snowflake_database.vancouver.name}.${snowflake_schema.raw.name}.${snowflake_stage.bronze_housing.name}"
  
  # DISPLAYS: "VANCOUVER_DATA.RAW.BRONZE_HOUSING_STAGE"
}

# ==========================================
# ROLE INFORMATION
# ==========================================

output "analyst_role_name" {
  description = "Name of analyst role"
  value       = snowflake_account_role.analyst.name
  
  # DISPLAYS: "VANCOUVER_ANALYST"
  # USE WHEN: Granting role to users
  # EXAMPLE: GRANT ROLE VANCOUVER_ANALYST TO USER john.doe@email.com;
}

# ==========================================
# CONNECTION STRING (for convenience)
# ==========================================

output "snowflake_connection_info" {
  description = "Connection information for Snowflake"
  value = {
    account   = var.snowflake_account_name
    database  = snowflake_database.vancouver.name
    warehouse = snowflake_warehouse.compute.name
    role      = "VANCOUVER_ANALYST"
  }
  
  # DISPLAYS:
  # {
  #   account   = "xy12345.us-east-1"
  #   database  = "VANCOUVER_DATA"
  #   warehouse = "VANCOUVER_WH"
  #   role      = "VANCOUVER_ANALYST"
  # }
  #
  # USE IN: Databricks connection configuration
  # USE IN: dbt profiles.yml
  # USE IN: BI tool connections (Tableau, PowerBI)
}

# ==========================================
# EXAMPLE SQL COMMANDS (helpful for testing)
# ==========================================

output "example_sql_commands" {
  description = "Example SQL commands to test your setup"
  value = <<-EOT
  
  -- Use the warehouse
  USE WAREHOUSE ${snowflake_warehouse.compute.name};
  
  -- Use the database
  USE DATABASE ${snowflake_database.vancouver.name};
  
  -- List files in crime stage
  LIST @${snowflake_schema.raw.name}.${snowflake_stage.bronze_crime.name};
  
  -- Query data directly from S3
  SELECT * 
  FROM @${snowflake_schema.raw.name}.${snowflake_stage.bronze_crime.name}
  LIMIT 10;
  
  -- Describe storage integration
  DESC INTEGRATION ${snowflake_storage_integration.s3.name};
  
  -- Check your current role
  SELECT CURRENT_ROLE();
  
  EOT
}

# ==========================================
# HOW TO USE THESE OUTPUTS:
# ==========================================
# After running 'terraform apply', you'll see:
#
# Outputs:
# database_name = "VANCOUVER_DATA"
# warehouse_name = "VANCOUVER_WH"
# storage_integration_arn = "arn:aws:iam::123456789:user/abc-s-xyz"
#
# MOST IMPORTANT OUTPUT:
# storage_integration_arn - Copy this and update AWS IAM trust policy!
#
# TO GET SPECIFIC OUTPUT:
# terraform output storage_integration_arn
#
# TO GET ALL OUTPUTS AS JSON:
# terraform output -json
# ==========================================