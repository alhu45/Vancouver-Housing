# ==========================================
# SUMMARY OF WHAT GETS CREATED:
# ==========================================
# ✅ Database: VANCOUVER_DATA
# ✅ Schemas: RAW, ANALYTICS, MARTS
# ✅ Warehouse: VANCOUVER_WH (X-SMALL, auto-suspend after 60s)
# ✅ Storage Integration: Links to your 3 S3 buckets
# ✅ External Stages: Pointers to crime/transit/housing folders in S3
# ✅ Role: VANCOUVER_ANALYST with read permissions (new syntax)
# ==========================================

# This file will create Snowflake Warehouse Infrastructure
# - Database
# - Schemas
# - Warehouse
# - S3 Connection

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


# terraform/snowflake/main.tf
# ==========================================
# UPDATED FOR SNOWFLAKE PROVIDER v0.94+
# ==========================================

# ==========================================
# PART 1: DATABASE (Top-level container)
# ==========================================

resource "snowflake_database" "vancouver" {
  name    = var.database_name
  comment = "Vancouver Housing Livability Index project data"
}

# ==========================================
# PART 2: SCHEMAS (Organize tables by layer)
# ==========================================

resource "snowflake_schema" "raw" {
  database = snowflake_database.vancouver.name
  name     = "RAW"
  comment  = "Raw data loaded directly from S3 (Bronze layer)"
}

resource "snowflake_schema" "analytics" {
  database = snowflake_database.vancouver.name
  name     = "ANALYTICS"
  comment  = "Cleaned and transformed data (Silver layer)"
}

resource "snowflake_schema" "marts" {
  database = snowflake_database.vancouver.name
  name     = "MARTS"
  comment  = "Business-ready data marts (Gold layer)"
}

# ==========================================
# PART 3: WAREHOUSE (Compute Engine)
# ==========================================

resource "snowflake_warehouse" "compute" {
  name           = var.warehouse_name
  warehouse_size = var.warehouse_size
  auto_suspend   = 60
  auto_resume    = true
  comment        = "Compute warehouse for Vancouver data processing"
}

# ==========================================
# PART 4: STORAGE INTEGRATION (Connect to S3)
# ==========================================

resource "snowflake_storage_integration" "s3" {
  name    = "VANCOUVER_S3_INTEGRATION"
  type    = "EXTERNAL_STAGE"
  enabled = true
  
  # REQUIRED in new version
  storage_provider = "S3"
  
  storage_allowed_locations = [
    "s3://${var.s3_bronze_bucket}/",
    "s3://${var.s3_silver_bucket}/",
    "s3://${var.s3_gold_bucket}/"
  ]
  
  storage_aws_role_arn = var.aws_iam_role_arn
  
  comment = "Integration with AWS S3 for Vancouver data lake"
}

# ==========================================
# PART 5: EXTERNAL STAGES (Point to S3 folders)
# ==========================================

resource "snowflake_stage" "bronze_crime" {
  name     = "BRONZE_CRIME_STAGE"
  database = snowflake_database.vancouver.name
  schema   = snowflake_schema.raw.name
  
  url = "s3://${var.s3_bronze_bucket}/crime/raw/"
  
  storage_integration = snowflake_storage_integration.s3.name
  
  file_format = "type = CSV field_optionally_enclosed_by = '\"' skip_header = 1"
}

resource "snowflake_stage" "bronze_transit" {
  name     = "BRONZE_TRANSIT_STAGE"
  database = snowflake_database.vancouver.name
  schema   = snowflake_schema.raw.name
  
  url = "s3://${var.s3_bronze_bucket}/transit/raw/"
  
  storage_integration = snowflake_storage_integration.s3.name
  
  file_format = "type = CSV field_optionally_enclosed_by = '\"' skip_header = 1"
}

resource "snowflake_stage" "bronze_housing" {
  name     = "BRONZE_HOUSING_STAGE"
  database = snowflake_database.vancouver.name
  schema   = snowflake_schema.raw.name
  
  url = "s3://${var.s3_bronze_bucket}/housing/raw/"
  
  storage_integration = snowflake_storage_integration.s3.name
  
  file_format = "type = JSON"
}

# ==========================================
# PART 6: ROLES & PERMISSIONS (Updated Syntax)
# ==========================================

# Create analyst role (using new resource type)
resource "snowflake_account_role" "analyst" {
  name    = "VANCOUVER_ANALYST"
  comment = "Role for data analysts working on Vancouver project"
}

# Grant database usage to analyst role
resource "snowflake_grant_privileges_to_account_role" "analyst_database" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.vancouver.name
  }
}

# Grant warehouse usage to analyst role
resource "snowflake_grant_privileges_to_account_role" "analyst_warehouse" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.compute.name
  }
}

# Grant schema usage for RAW
resource "snowflake_grant_privileges_to_account_role" "analyst_raw_schema" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  
  on_schema {
    schema_name = "\"${snowflake_database.vancouver.name}\".\"${snowflake_schema.raw.name}\""
  }
}

# Grant schema usage for ANALYTICS
resource "snowflake_grant_privileges_to_account_role" "analyst_analytics_schema" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  
  on_schema {
    schema_name = "\"${snowflake_database.vancouver.name}\".\"${snowflake_schema.analytics.name}\""
  }
}

# Grant schema usage for MARTS
resource "snowflake_grant_privileges_to_account_role" "analyst_marts_schema" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  
  on_schema {
    schema_name = "\"${snowflake_database.vancouver.name}\".\"${snowflake_schema.marts.name}\""
  }
}

# Grant SELECT on future tables in ANALYTICS
resource "snowflake_grant_privileges_to_account_role" "analyst_analytics_tables" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["SELECT"]
  
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.vancouver.name}\".\"${snowflake_schema.analytics.name}\""
    }
  }
}

# Grant SELECT on future tables in MARTS
resource "snowflake_grant_privileges_to_account_role" "analyst_marts_tables" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["SELECT"]
  
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.vancouver.name}\".\"${snowflake_schema.marts.name}\""
    }
  }
}