terraform {
    required_version = ">=1.0"

    required_providers {
        snowflake = {
            source  = "Snowflake-Labs/snowflake"
            version = "~> 1.0" 
        }
    }
}

provider "snowflake" {
    organization_name = var.snowflake_organization
    account_name = var.snowflake_account_name

    user = "TERRAFORM_SVC"
    role = "ACCOUNTADMIN"

    authenticator = "SNOWFLAKE_JWT"
    private_key = file(var.snowflake_private_key_path)

    preview_features_enabled = ["snowflake_storage_integration_resource", "snowflake_stage_resource"]
}

