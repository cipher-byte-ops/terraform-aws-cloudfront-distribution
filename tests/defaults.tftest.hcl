mock_provider "aws" {}

variables {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
  name = "example"
  origins = {
    assets = { domain_name = "assets.s3.us-east-1.amazonaws.com" }
    api    = { domain_name = "abc.execute-api.us-east-1.amazonaws.com", custom = {} }
    bound  = { domain_name = "bound.s3.us-east-1.amazonaws.com", origin_access_control_id = "E123EXISTING" }
  }
  default_behavior = {
    origin          = "api"
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    functions       = { viewer-request = "arn:aws:cloudfront::123456789012:function/rewrite" }
  }
  ordered_behaviors = [
    { path_pattern = "assets/*", origin = "assets", cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" },
    { path_pattern = "bound/*", origin = "bound", cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" },
  ]
}

run "test_oac_only_for_s3_origins_without_one" {
  command = plan

  assert {
    condition     = keys(local.origin_access_control) == ["assets"]
    error_message = "An access control is created only for S3 origins that bring none."
  }

  assert {
    condition     = local.origins["assets"].origin_access_control_key == "assets" && local.origins["bound"].origin_access_control_key == null && local.origins["api"].origin_access_control_key == null
    error_message = "Only the generated access control is referenced by key."
  }

  assert {
    condition     = local.origins["bound"].origin_access_control_id == "E123EXISTING"
    error_message = "A supplied access control id must be passed through."
  }
}

run "test_custom_origin_defaults" {
  command = plan

  assert {
    condition     = local.origins["api"].custom_origin_config.origin_protocol_policy == "https-only" && local.origins["api"].custom_origin_config.origin_ssl_protocols == tolist(["TLSv1.2"])
    error_message = "Custom origins default to https-only with TLSv1.2."
  }

  assert {
    condition     = local.origins["assets"].custom_origin_config == null
    error_message = "S3 origins have no custom origin config."
  }
}

run "test_https_redirect_everywhere" {
  command = plan

  assert {
    condition     = local.default_cache_behavior.viewer_protocol_policy == "redirect-to-https" && alltrue([for b in local.ordered_cache_behavior : b.viewer_protocol_policy == "redirect-to-https"])
    error_message = "Every behavior must redirect viewers to HTTPS."
  }

  assert {
    condition     = output.viewer_protocol_policy == "redirect-to-https"
    error_message = "viewer_protocol_policy output must be redirect-to-https."
  }
}

run "test_behavior_order_and_functions" {
  command = plan

  assert {
    condition     = [for b in local.ordered_cache_behavior : b.path_pattern] == ["assets/*", "bound/*"]
    error_message = "Ordered behaviors must keep their order."
  }

  assert {
    condition     = local.default_cache_behavior.function_association["viewer-request"].function_arn == "arn:aws:cloudfront::123456789012:function/rewrite"
    error_message = "Viewer functions must be associated by event type."
  }
}

run "test_default_certificate_without_aliases" {
  command = plan

  assert {
    condition     = local.viewer_certificate.cloudfront_default_certificate == true
    error_message = "Without a certificate the default CloudFront certificate is used."
  }

  assert {
    condition     = local.viewer_certificate.minimum_protocol_version == "TLSv1"
    error_message = "The default CloudFront certificate is limited to TLSv1."
  }
}

run "test_acm_certificate_with_aliases" {
  command = plan

  variables {
    aliases         = ["www.example.com"]
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = local.viewer_certificate.ssl_support_method == "sni-only" && local.viewer_certificate.minimum_protocol_version == "TLSv1.2_2021"
    error_message = "An ACM certificate is served over SNI with TLSv1.2_2021."
  }
}

run "test_aliases_need_certificate" {
  command = plan

  variables {
    aliases = ["www.example.com"]
  }

  expect_failures = [var.aliases]
}

run "test_origin_reference_validation" {
  command = plan

  variables {
    default_behavior = {
      origin          = "missing"
      cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    }
  }

  expect_failures = [var.default_behavior]
}

run "test_function_event_validation" {
  command = plan

  variables {
    default_behavior = {
      origin          = "api"
      cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
      functions       = { origin-request = "arn:aws:cloudfront::123456789012:function/x" }
    }
  }

  expect_failures = [var.default_behavior]
}

run "test_tags_contract" {
  command = plan

  variables {
    tags = { Owner = "x" }
    context = {
      organization = "olensys"
      environment  = "test"
      application  = "example"
      owner        = "platform"
      cost_center  = "eng"
      extra_tags   = { Owner = "y", Team = "z" }
    }
  }

  assert {
    condition     = output.tags.Owner == "x" && output.tags.Team == "z"
    error_message = "var.tags must win over context.extra_tags, which is still merged."
  }
}

run "test_price_class_validation" {
  command = plan

  variables {
    price_class = "PriceClass_50"
  }

  expect_failures = [var.price_class]
}
