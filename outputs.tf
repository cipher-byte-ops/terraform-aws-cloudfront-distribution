output "id" {
  description = "ID of the CloudFront distribution. Null when create is false."
  value       = var.create ? module.this.cloudfront_distribution_id : null
}

output "name" {
  description = "Name of the distribution. Null when create is false."
  value       = var.create ? var.name : null
}

output "arn" {
  description = "ARN of the CloudFront distribution. Null when create is false."
  value       = var.create ? module.this.cloudfront_distribution_arn : null
}

output "domain_name" {
  description = "CloudFront domain name; point the aliases' CNAME records here. Null when create is false."
  value       = var.create ? module.this.cloudfront_distribution_domain_name : null
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID of CloudFront, for alias records. Null when create is false."
  value       = var.create ? module.this.cloudfront_distribution_hosted_zone_id : null
}

output "origin_access_control_ids" {
  description = "IDs of the origin access controls created by this module, keyed by origin. Empty when every S3 origin brought its own or create is false."
  value       = var.create ? { for k, v in module.this.cloudfront_origin_access_controls : k => v.id } : {}
}

output "tags" {
  description = "Tags applied to every taggable resource, with context.extra_tags merged in. Null when create is false."
  value       = var.create ? local.tags : null
}

output "viewer_protocol_policy" {
  description = "Viewer protocol policy of every cache behavior. Null when create is false."
  value       = var.create ? local.viewer_protocol_policy : null
}
