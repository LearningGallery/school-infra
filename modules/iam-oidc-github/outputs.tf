output "release_role_arn" {
  description = "Set as the AWS_RELEASE_ROLE_ARN repository variable."
  value       = aws_iam_role.release.arn
}

output "pull_role_arn" {
  description = "Set as the AWS_PULL_ROLE_ARN variable on each GitHub Environment."
  value       = aws_iam_role.pull.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider in use."
  value       = local.provider_arn
}
