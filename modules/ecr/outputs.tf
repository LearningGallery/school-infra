output "repository_arns" {
  description = "Repository ARNs by name."
  value       = { for k, r in aws_ecr_repository.this : k => r.arn }
}

output "repository_urls" {
  description = "Repository URLs by name."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}
