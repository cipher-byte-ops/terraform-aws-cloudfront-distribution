# terraform-aws-cloudfront-distribution

CloudFront distribution with S3 and custom origins, ordered behaviours, HTTPS-only viewers and origin access control

## Opinions

- Every behaviour redirects viewers to HTTPS (`viewer_protocol_policy = "redirect-to-https"`); certificates are served over SNI with minimum protocol `TLSv1.2_2021`.
- An origin without `custom` is an S3 origin behind origin access control (SigV4, always signing), never origin access identity. Give it an existing control with `origin_access_control_id`, or the module creates one named `<name>-<origin key>`.
- An origin with `custom` is any HTTP(S) server, for example an API Gateway or load balancer domain. It defaults to `https-only` with TLSv1.2.
- `http_version = "http2and3"`, IPv6 enabled, `wait_for_deployment = false`; `price_class` defaults to `PriceClass_100`.
- Cache, origin request and response headers policies are passed in by id, so a stack can use the AWS managed policies or its own. CloudFront functions are attached by ARN, at most one per `viewer-request` or `viewer-response`.
- `ordered_behaviors` are matched in the order given before the default behaviour.
- Without `aliases` and `certificate_arn` the distribution is served on its own domain with the default CloudFront certificate (CloudFront limits it to `TLSv1`).
- The certificate must be in `us-east-1`: pass the `terraform-aws-acm-certificate` output, created with an aliased `us-east-1` provider.
- The bucket and its policy are the caller's job: allow `cloudfront.amazonaws.com` to read it with `AWS:SourceArn` set to the `arn` output. For a site with a single S3 origin use `terraform-aws-static-site`, which creates the bucket too.
- DNS is the consumer's job: point a CNAME for each of `aliases` at the `domain_name` output with `terraform-cloudflare-dns` or Route53.
- Integration: `examples/minimal` fronts a custom origin on the distribution's own domain and needs no certificate; `AWS_REGION` comes from the environment.

## Usage

```hcl
module "naming" {
  source  = "git::https://github.com/Olensys/terraform-null-naming.git?ref=v1.0.1"
  context = var.context
}

module "distribution" {
  source  = "git::https://github.com/Olensys/terraform-aws-cloudfront-distribution.git?ref=v0.1.0"
  name    = module.naming.name
  context = var.context

  origins = {
    assets = { domain_name = aws_s3_bucket.assets.bucket_regional_domain_name }
    api    = { domain_name = "abc123.execute-api.us-east-1.amazonaws.com", custom = {} }
  }

  default_behavior = {
    origin          = "api"
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
  }

  ordered_behaviors = [
    {
      path_pattern    = "assets/*"
      origin          = "assets"
      cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    },
  ]

  aliases         = ["www.example.com"]
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"

  tags = module.naming.tags
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_this"></a> [this](#module\_this) | terraform-aws-modules/cloudfront/aws | 6.7.1 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_context"></a> [context](#input\_context) | Deployment context used for naming, tagging and environment-dependent defaults. | <pre>object({<br/>    organization = string<br/>    environment  = string<br/>    application  = string<br/>    component    = optional(string)<br/>    owner        = string<br/>    cost_center  = string<br/>    extra_tags   = optional(map(string), {})<br/>  })</pre> | n/a | yes |
| <a name="input_default_behavior"></a> [default\_behavior](#input\_default\_behavior) | Default cache behavior. origin is a key of origins. Viewers are always redirected to HTTPS. functions maps a viewer event (viewer-request or viewer-response) to a CloudFront function ARN. | <pre>object({<br/>    origin                     = string<br/>    cache_policy_id            = string<br/>    origin_request_policy_id   = optional(string)<br/>    response_headers_policy_id = optional(string)<br/>    allowed_methods            = optional(list(string), ["GET", "HEAD", "OPTIONS"])<br/>    cached_methods             = optional(list(string), ["GET", "HEAD"])<br/>    compress                   = optional(bool, true)<br/>    functions                  = optional(map(string), {})<br/>  })</pre> | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Resource name, used as the distribution comment and to name the origin access controls. Lowercase letters, digits and hyphens. | `string` | n/a | yes |
| <a name="input_origins"></a> [origins](#input\_origins) | Origins keyed by name. An origin without custom is an S3 bucket origin: domain\_name is the bucket regional domain name and access goes through origin access control (the one given in origin\_access\_control\_id, or one created by this module). An origin with custom is any HTTPS or HTTP server, such as an API Gateway or load balancer domain. | <pre>map(object({<br/>    domain_name              = string<br/>    path                     = optional(string)<br/>    origin_access_control_id = optional(string)<br/>    custom = optional(object({<br/>      protocol_policy   = optional(string, "https-only")<br/>      http_port         = optional(number, 80)<br/>      https_port        = optional(number, 443)<br/>      ssl_protocols     = optional(list(string), ["TLSv1.2"])<br/>      read_timeout_s    = optional(number, 30)<br/>      keepalive_timeout = optional(number, 5)<br/>    }))<br/>  }))</pre> | n/a | yes |
| <a name="input_aliases"></a> [aliases](#input\_aliases) | Alternate domain names (CNAMEs) served by the distribution. Must be covered by the certificate. Empty serves the distribution on its own domain with the default CloudFront certificate. | `list(string)` | `[]` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ARN of the ACM certificate for aliases. Must be issued in us-east-1. Null uses the default CloudFront certificate. | `string` | `null` | no |
| <a name="input_create"></a> [create](#input\_create) | Whether to create any resources. Set false to create nothing. | `bool` | `true` | no |
| <a name="input_custom_error_responses"></a> [custom\_error\_responses](#input\_custom\_error\_responses) | Custom error responses, for example mapping 403 and 404 to a page. Empty keeps the origin's errors. | <pre>list(object({<br/>    error_code         = number<br/>    response_code      = optional(number)<br/>    response_page_path = optional(string)<br/>    min_ttl_s          = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_default_root_object"></a> [default\_root\_object](#input\_default\_root\_object) | Object returned for requests to the root URL, for example index.html. Empty returns whatever the origin serves at /. | `string` | `""` | no |
| <a name="input_logging_bucket"></a> [logging\_bucket](#input\_logging\_bucket) | Domain name of an S3 bucket (for example my-logs.s3.amazonaws.com) that receives access logs. Null disables logging. | `string` | `null` | no |
| <a name="input_ordered_behaviors"></a> [ordered\_behaviors](#input\_ordered\_behaviors) | Cache behaviors matched before the default one, in order of precedence (first match wins). Same fields as default\_behavior plus the path\_pattern they match. | <pre>list(object({<br/>    path_pattern               = string<br/>    origin                     = string<br/>    cache_policy_id            = string<br/>    origin_request_policy_id   = optional(string)<br/>    response_headers_policy_id = optional(string)<br/>    allowed_methods            = optional(list(string), ["GET", "HEAD", "OPTIONS"])<br/>    cached_methods             = optional(list(string), ["GET", "HEAD"])<br/>    compress                   = optional(bool, true)<br/>    functions                  = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input_price_class"></a> [price\_class](#input\_price\_class) | Edge locations used: PriceClass\_100, PriceClass\_200 or PriceClass\_All. | `string` | `"PriceClass_100"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags merged onto every taggable resource, applied last. | `map(string)` | `{}` | no |
| <a name="input_web_acl_arn"></a> [web\_acl\_arn](#input\_web\_acl\_arn) | ARN of a WAFv2 web ACL (created in us-east-1) to attach. Null attaches none. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the CloudFront distribution. Null when create is false. |
| <a name="output_domain_name"></a> [domain\_name](#output\_domain\_name) | CloudFront domain name; point the aliases' CNAME records here. Null when create is false. |
| <a name="output_hosted_zone_id"></a> [hosted\_zone\_id](#output\_hosted\_zone\_id) | Route 53 hosted zone ID of CloudFront, for alias records. Null when create is false. |
| <a name="output_id"></a> [id](#output\_id) | ID of the CloudFront distribution. Null when create is false. |
| <a name="output_name"></a> [name](#output\_name) | Name of the distribution. Null when create is false. |
| <a name="output_origin_access_control_ids"></a> [origin\_access\_control\_ids](#output\_origin\_access\_control\_ids) | IDs of the origin access controls created by this module, keyed by origin. Empty when every S3 origin brought its own or create is false. |
| <a name="output_tags"></a> [tags](#output\_tags) | Tags applied to every taggable resource, with context.extra\_tags merged in. Null when create is false. |
| <a name="output_viewer_protocol_policy"></a> [viewer\_protocol\_policy](#output\_viewer\_protocol\_policy) | Viewer protocol policy of every cache behavior. Null when create is false. |
<!-- END_TF_DOCS -->
