variable "name" {
  description = "Resource name, used as the distribution comment and to name the origin access controls. Lowercase letters, digits and hyphens."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{1,63}$", var.name))
    error_message = "name must match ^[a-z0-9-]{1,63}$."
  }
}

variable "context" {
  description = "Deployment context used for naming, tagging and environment-dependent defaults."
  type = object({
    organization = string
    environment  = string
    application  = string
    component    = optional(string)
    owner        = string
    cost_center  = string
    extra_tags   = optional(map(string), {})
  })
  validation {
    condition     = contains(["dev", "staging", "prod", "test", "shared"], var.context.environment)
    error_message = "context.environment must be one of dev, staging, prod, test, shared."
  }
}

variable "create" {
  description = "Whether to create any resources. Set false to create nothing."
  type        = bool
  default     = true
}

variable "origins" {
  description = "Origins keyed by name. An origin without custom is an S3 bucket origin: domain_name is the bucket regional domain name and access goes through origin access control (the one given in origin_access_control_id, or one created by this module). An origin with custom is any HTTPS or HTTP server, such as an API Gateway or load balancer domain."
  type = map(object({
    domain_name              = string
    path                     = optional(string)
    origin_access_control_id = optional(string)
    custom = optional(object({
      protocol_policy   = optional(string, "https-only")
      http_port         = optional(number, 80)
      https_port        = optional(number, 443)
      ssl_protocols     = optional(list(string), ["TLSv1.2"])
      read_timeout_s    = optional(number, 30)
      keepalive_timeout = optional(number, 5)
    }))
  }))
  validation {
    condition     = length(var.origins) > 0
    error_message = "origins must define at least one origin."
  }
  validation {
    condition     = alltrue([for o in var.origins : o.custom == null ? true : contains(["https-only", "http-only", "match-viewer"], o.custom.protocol_policy)])
    error_message = "origins[*].custom.protocol_policy must be https-only, http-only or match-viewer."
  }
}

variable "default_behavior" {
  description = "Default cache behavior. origin is a key of origins. Viewers are always redirected to HTTPS. functions maps a viewer event (viewer-request or viewer-response) to a CloudFront function ARN."
  type = object({
    origin                     = string
    cache_policy_id            = string
    origin_request_policy_id   = optional(string)
    response_headers_policy_id = optional(string)
    allowed_methods            = optional(list(string), ["GET", "HEAD", "OPTIONS"])
    cached_methods             = optional(list(string), ["GET", "HEAD"])
    compress                   = optional(bool, true)
    functions                  = optional(map(string), {})
  })
  validation {
    condition     = contains(keys(var.origins), var.default_behavior.origin)
    error_message = "default_behavior.origin must be a key of origins."
  }
  validation {
    condition     = alltrue([for e in keys(var.default_behavior.functions) : contains(["viewer-request", "viewer-response"], e)])
    error_message = "default_behavior.functions keys must be viewer-request or viewer-response."
  }
}

variable "ordered_behaviors" {
  description = "Cache behaviors matched before the default one, in order of precedence (first match wins). Same fields as default_behavior plus the path_pattern they match."
  type = list(object({
    path_pattern               = string
    origin                     = string
    cache_policy_id            = string
    origin_request_policy_id   = optional(string)
    response_headers_policy_id = optional(string)
    allowed_methods            = optional(list(string), ["GET", "HEAD", "OPTIONS"])
    cached_methods             = optional(list(string), ["GET", "HEAD"])
    compress                   = optional(bool, true)
    functions                  = optional(map(string), {})
  }))
  default = []
  validation {
    condition     = alltrue([for b in var.ordered_behaviors : contains(keys(var.origins), b.origin)])
    error_message = "ordered_behaviors[*].origin must be a key of origins."
  }
  validation {
    condition     = alltrue([for b in var.ordered_behaviors : alltrue([for e in keys(b.functions) : contains(["viewer-request", "viewer-response"], e)])])
    error_message = "ordered_behaviors[*].functions keys must be viewer-request or viewer-response."
  }
}

variable "aliases" {
  description = "Alternate domain names (CNAMEs) served by the distribution. Must be covered by the certificate. Empty serves the distribution on its own domain with the default CloudFront certificate."
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.aliases) == 0 || var.certificate_arn != null
    error_message = "certificate_arn is required when aliases is set."
  }
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for aliases. Must be issued in us-east-1. Null uses the default CloudFront certificate."
  type        = string
  default     = null
}

variable "default_root_object" {
  description = "Object returned for requests to the root URL, for example index.html. Empty returns whatever the origin serves at /."
  type        = string
  default     = ""
}

variable "custom_error_responses" {
  description = "Custom error responses, for example mapping 403 and 404 to a page. Empty keeps the origin's errors."
  type = list(object({
    error_code         = number
    response_code      = optional(number)
    response_page_path = optional(string)
    min_ttl_s          = optional(number)
  }))
  default = []
}

variable "price_class" {
  description = "Edge locations used: PriceClass_100, PriceClass_200 or PriceClass_All."
  type        = string
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }
}

variable "web_acl_arn" {
  description = "ARN of a WAFv2 web ACL (created in us-east-1) to attach. Null attaches none."
  type        = string
  default     = null
}

variable "logging_bucket" {
  description = "Domain name of an S3 bucket (for example my-logs.s3.amazonaws.com) that receives access logs. Null disables logging."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags merged onto every taggable resource, applied last."
  type        = map(string)
  default     = {}
}
