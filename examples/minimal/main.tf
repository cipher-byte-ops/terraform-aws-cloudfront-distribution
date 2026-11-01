terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 6.0, < 7.0" }
  }
}

# Region comes from the environment.
provider "aws" {}

# AWS managed policies: CachingDisabled and AllViewerExceptHostHeader.
data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

module "this" {
  source = "../../"

  name = "olensys-test-distribution"
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "distribution"
    owner        = "platform"
    cost_center  = "eng"
  }

  # A custom origin keeps the example free of buckets; it serves on the distribution's own domain.
  origins = {
    web = {
      domain_name = "example.com"
      custom      = {}
    }
  }

  default_behavior = {
    origin          = "web"
    cache_policy_id = data.aws_cloudfront_cache_policy.disabled.id
  }
}

output "domain_name" {
  description = "CloudFront distribution domain name."
  value       = module.this.domain_name
}
