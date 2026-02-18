terraform {
    required_version = ">=1.0"

    required_providers {
        snowflake = {
            source  = "Snowflake-Labs/snowflake"
            version = "~> 0.94" 
        }
    }
}

provider "snowflake" {
    organization_name = var.snowflake_organization
    account_name      = var.snowflake_account_name


    user        = "TERRAFORM_SVC"
    role        = "ACCOUNTADMIN"

    authenticator = "JWT"
    
    private_key = file(var.snowflake_private_key_path)
}

