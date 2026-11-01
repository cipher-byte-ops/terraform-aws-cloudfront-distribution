# One upstream call: the CloudFront distribution, with the origin access controls it needs.

locals {
  # Merge onto every taggable resource, with var.tags applied last.
  tags = merge(var.context.extra_tags, var.tags)

  viewer_protocol_policy = "redirect-to-https"

  # S3 origins without an existing access control get one created here, named after the distribution.
  generated_oac_origins = var.create ? [
    for k, o in var.origins : k if o.custom == null && o.origin_access_control_id == null
  ] : []

  origin_access_control = {
    for k in local.generated_oac_origins : k => {
      description      = "Origin access control for ${var.name} (${k})"
      name             = "${var.name}-${k}"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origins = {
    for k, o in var.origins : k => {
      domain_name               = o.domain_name
      origin_path               = o.path
      origin_access_control_id  = o.origin_access_control_id
      origin_access_control_key = contains(local.generated_oac_origins, k) ? k : null
      custom_origin_config = o.custom == null ? null : {
        http_port                = o.custom.http_port
        https_port               = o.custom.https_port
        origin_protocol_policy   = o.custom.protocol_policy
        origin_ssl_protocols     = o.custom.ssl_protocols
        origin_read_timeout      = o.custom.read_timeout_s
        origin_keepalive_timeout = o.custom.keepalive_timeout
      }
    }
  }

  default_cache_behavior = {
    target_origin_id           = var.default_behavior.origin
    viewer_protocol_policy     = local.viewer_protocol_policy
    allowed_methods            = var.default_behavior.allowed_methods
    cached_methods             = var.default_behavior.cached_methods
    compress                   = var.default_behavior.compress
    cache_policy_id            = var.default_behavior.cache_policy_id
    origin_request_policy_id   = var.default_behavior.origin_request_policy_id
    response_headers_policy_id = var.default_behavior.response_headers_policy_id
    function_association = {
      for e, arn in var.default_behavior.functions : e => { event_type = e, function_arn = arn }
    }
  }

  ordered_cache_behavior = [
    for b in var.ordered_behaviors : {
      path_pattern               = b.path_pattern
      target_origin_id           = b.origin
      viewer_protocol_policy     = local.viewer_protocol_policy
      allowed_methods            = b.allowed_methods
      cached_methods             = b.cached_methods
      compress                   = b.compress
      cache_policy_id            = b.cache_policy_id
      origin_request_policy_id   = b.origin_request_policy_id
      response_headers_policy_id = b.response_headers_policy_id
      function_association = {
        for e, arn in b.functions : e => { event_type = e, function_arn = arn }
      }
    }
  ]

  custom_error_response = [
    for e in var.custom_error_responses : {
      error_code            = e.error_code
      response_code         = e.response_code
      response_page_path    = e.response_page_path
      error_caching_min_ttl = e.min_ttl_s
    }
  ]

  # CloudFront fixes the minimum protocol at TLSv1 for its default certificate.
  viewer_certificate = {
    cloudfront_default_certificate = var.certificate_arn == null ? true : null
    acm_certificate_arn            = var.certificate_arn
    ssl_support_method             = var.certificate_arn == null ? null : "sni-only"
    minimum_protocol_version       = var.certificate_arn == null ? "TLSv1" : "TLSv1.2_2021"
  }
}

module "this" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "6.7.1"

  create              = var.create
  comment             = var.name
  enabled             = true
  aliases             = var.aliases
  default_root_object = var.default_root_object
  price_class         = var.price_class
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  web_acl_id          = var.web_acl_arn
  wait_for_deployment = false

  origin_access_control = local.origin_access_control
  origin                = local.origins

  default_cache_behavior = local.default_cache_behavior
  ordered_cache_behavior = local.ordered_cache_behavior
  custom_error_response  = length(local.custom_error_response) == 0 ? null : local.custom_error_response

  viewer_certificate = local.viewer_certificate

  logging_config = var.logging_bucket == null ? null : {
    bucket          = var.logging_bucket
    include_cookies = false
    prefix          = var.name
  }

  tags = local.tags
}
