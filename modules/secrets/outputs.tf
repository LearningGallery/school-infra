output "app_secret_arn" {
  value = aws_secretsmanager_secret.app.arn
}

output "app_secret_name" {
  value = aws_secretsmanager_secret.app.name
}

output "eso_role_arn" {
  value = aws_iam_role.eso.arn
}
