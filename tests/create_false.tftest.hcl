mock_provider "aws" {}

variables {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
  name   = "example"
  create = false
  origins = {
    assets = { domain_name = "assets.s3.us-east-1.amazonaws.com" }
  }
  default_behavior = {
    origin          = "assets"
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }
}

run "test_create_false_plans_nothing" {
  command = plan

  assert {
    condition     = output.id == null && output.arn == null && output.name == null && output.domain_name == null && output.tags == null
    error_message = "Outputs must be null when create is false."
  }

  assert {
    condition     = length(local.origin_access_control) == 0
    error_message = "No access control is planned when create is false."
  }

  assert {
    condition     = length(output.origin_access_control_ids) == 0
    error_message = "No access control ids are exposed when create is false."
  }
}
