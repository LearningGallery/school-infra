output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "namespaces" {
  value = ["kube-system", "external-secrets", "argocd", "argo-rollouts", "monitoring"]
}
