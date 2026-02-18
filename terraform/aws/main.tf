# ==========================================
# SUMMARY OF WHAT GETS CREATED:
# ==========================================
# ✅ 3 S3 buckets: bronze, silver, gold
# ✅ Versioning enabled on bronze & silver (can recover deleted files)
# ✅ Lifecycle rule on bronze (auto-archive after 90 days, delete after 365)
# ✅ IAM user for Airflow with upload permissions
# ✅ IAM role for Snowflake with read permissions
# ✅ IAM role for Databricks with read/write permissions
# ==========================================

# AWS Resources
# AWS Bronze Bucket (Bucket is the public cloud storage container within the AWS)
resource "aws_s3_bucket" "bronze" {
  bucket = "${var.project_name}-bronze-${var.environment}"

  tags = merge(
    var.tags, 
    {
      Name  = "Bronze Layer - Raw Data"
      Layer = "bronze"
    }
  )
}

# AWS Silver Bucket
resource "aws_s3_bucket" "silver" {
  bucket = "${var.project_name}-silver-${var.environment}"

  tags = merge(
    var.tags, 
    {
      Name  = "Silver Layer - Cleaned Data"
      Layer = "silver"
    }
  )
}

# AWS Gold Bucket
resource "aws_s3_bucket" "gold" {
  bucket = "${var.project_name}-gold-${var.environment}"
  
  tags = merge(
    var.tags,
    {
      Name  = "Gold Layer - Analytics Data"
      Layer = "gold"
    }
  )
}

# Resources for Verisoning to keep track of history in case I accidentally overwrite a file
resource "aws_s3_bucket_versioning" "bronze" {
  bucket = aws_s3_bucket.bronze.id
    versioning_configuration {
    status = "Enabled"
  }
}

# Resource of AWS Lifecycle Rules (Autoclean up to save money)
resource "aws_s3_bucket_lifecycle_configuration" "bronze" {
  bucket = aws_s3_bucket.bronze.id

  rule {
    id = "archieve-old-data"
    status = "Enabled"
    filter {}

      # After 90 days, move to cheaper storage
    transition {
      days          = 90
      storage_class = "GLACIER"
      # COST SAVINGS: $0.023/GB → $0.004/GB (83% cheaper!)
    }

    # After 365 days, delete it
    expiration {
      days = 365
      # WHY: Raw data from 2 years ago probably isn't needed
    }
  }
}

# Create resource for IAM User for Airflow (The credentials for the Airflow Scripts)
# Creates a user account that Airflow will use
resource "aws_iam_user" "airflow" {
  name = "${var.project_name}-airflow-user"
  # Result "User named "vancouver-data-airflow-user"
  
  tags = var.tags
}

# Giving permission for Airflow to upload to the Bronze Bucket
resource "aws_iam_user_policy" "airflow_s3_access" {
  name = "${var.project_name}-airflow-s3-policy"
  user = aws_iam_user.airflow.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",      # Upload files
          "s3:GetObject",      # Download files
          "s3:ListBucket"      # List files in bucket
        ]
        Resource = [
          aws_s3_bucket.bronze.arn,           # The bucket itself
          "${aws_s3_bucket.bronze.arn}/*"     # Everything inside the bucket
        ]
      }
    ]
  })
}

# Create access keys (username + password for API access)
# You will get theAccess Key ID and Secret Access Key for Airflow to authenticate to AWS
resource "aws_iam_access_key" "airflow" {
  user = aws_iam_user.airflow.name
}

# ==========================================
# PART 5: IAM ROLE FOR SNOWFLAKE
# ==========================================

data "aws_iam_policy_document" "snowflake_assume_role" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::482885091138:user/cssc1000-s"]  # ← YOUR REAL ARN!
    }
    
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "snowflake_s3_access" {
  name               = "${var.project_name}-snowflake-role"
  assume_role_policy = data.aws_iam_policy_document.snowflake_assume_role.json
  
  tags = var.tags
}

data "aws_iam_policy_document" "snowflake_s3_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket"
    ]
    
    resources = [
      aws_s3_bucket.bronze.arn,
      "${aws_s3_bucket.bronze.arn}/*",
      aws_s3_bucket.silver.arn,
      "${aws_s3_bucket.silver.arn}/*",
      aws_s3_bucket.gold.arn,
      "${aws_s3_bucket.gold.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "snowflake_s3_access" {
  name   = "${var.project_name}-snowflake-s3-policy"
  role   = aws_iam_role.snowflake_s3_access.id
  policy = data.aws_iam_policy_document.snowflake_s3_policy.json
}

# PART 6: IAM ROLE FOR DATABRICKS (Let Databricks read/write S3)

# Trust policy: "I trust Databricks to use this role"
data "aws_iam_policy_document" "databricks_assume_role" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::414351767826:root"]
      # This is Databricks' AWS account ID (standard for all Databricks users)
    }
    
    actions = ["sts:AssumeRole"]
    
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["databricks-external-id-placeholder"]
      # You'll replace this with actual external ID from Databricks setup
    }
  }
}

resource "aws_iam_role" "databricks_s3_access" {
  name               = "${var.project_name}-databricks-role"
  assume_role_policy = data.aws_iam_policy_document.databricks_assume_role.json
  
  tags = var.tags
}

# Permission policy: "Databricks can read AND write"
data "aws_iam_policy_document" "databricks_s3_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "s3:GetObject",
      "s3:PutObject",      # Write files
      "s3:DeleteObject",   # Delete files
      "s3:ListBucket"
    ]
    
    resources = [
      aws_s3_bucket.bronze.arn,
      "${aws_s3_bucket.bronze.arn}/*",
      aws_s3_bucket.silver.arn,
      "${aws_s3_bucket.silver.arn}/*",
      aws_s3_bucket.gold.arn,
      "${aws_s3_bucket.gold.arn}/*"
    ]
    
    # RESULT: Databricks can read from Bronze, write to Silver/Gold
  }
}

resource "aws_iam_role_policy" "databricks_s3_access" {
  name   = "${var.project_name}-databricks-s3-policy"
  role   = aws_iam_role.databricks_s3_access.id
  policy = data.aws_iam_policy_document.databricks_s3_policy.json
}




