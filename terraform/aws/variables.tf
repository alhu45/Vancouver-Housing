variable "aws_region" {
    type = string
    default = "us-east-2"
}

variable "project_name" {
    description = "Project Name"
    type = string
    default = "vancouver-data"
}

variable "environment" {
    description = "Environment name (dev, staging, prod)"
    type = string
    default = "dev"
}

variable "tags" {
  description = "Tags applied to all AWS resources for organization"
  type        = map(string)
  default = {
    Project     = "Vancouver Housing Livability"
    ManagedBy   = "Terraform"
    Owner       = "Alan Hu"  
    Environment = "Development"
  }
  
}