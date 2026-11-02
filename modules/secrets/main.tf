# The application's own secret. The value is generated here and lives only in Secrets Manager and
# Terraform state (encrypt and restrict the state bucket). Rotation is a follow-up: see module 13.
resource "random_password" "jwt" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "app" {
  #checkov:skip=CKV2_AWS_57:Rotating the JWT signing secret needs application support for two valid keys at once (module 13 follow-up). The database master secret IS rotated by RDS.
  name                    = "school/${var.name}/app"
  description             = "School API runtime secrets"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id     = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({ jwt_secret = random_password.jwt.result })
}

# ---- External Secrets Operator identity (EKS Pod Identity) ----
data "aws_iam_policy_document" "eso_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eso_permissions" {
  statement {
    sid       = "ReadSchoolSecrets"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = concat([aws_secretsmanager_secret.app.arn], var.extra_secret_arns)
  }
  statement {
    sid       = "DecryptSchoolSecrets"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = concat([var.kms_key_arn], var.extra_kms_key_arns)
  }
}

resource "aws_iam_role" "eso" {
  name               = "${var.name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.eso_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "eso" {
  name   = "read-school-secrets"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.eso_permissions.json
}

resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = var.cluster_name
  namespace       = var.eso_namespace
  service_account = var.eso_service_account
  role_arn        = aws_iam_role.eso.arn
  tags            = var.tags
}
