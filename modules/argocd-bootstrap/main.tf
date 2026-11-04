# Installs the platform controllers once, with Helm, so Argo CD exists. From then on Argo CD manages
# itself and everything else from Git (school-gitops, Phase 4): this module is a bootstrap, not the
# long-term owner. Apply the root Application afterwards:  kubectl apply -f school-gitops/apps/root.yaml

# ---- AWS Load Balancer Controller: turns Ingress objects into ALBs / weighted target groups ----
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

# Policy published by the controller project, pinned to the controller release in files/.
resource "aws_iam_role_policy" "alb_controller" {
  name   = "aws-load-balancer-controller"
  role   = aws_iam_role.alb_controller.id
  policy = file("${path.module}/files/alb-controller-iam-policy.json")
}

resource "aws_eks_pod_identity_association" "alb_controller" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.alb_controller.arn
  tags            = var.tags
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_versions["aws-load-balancer-controller"]
  namespace  = "kube-system"
  timeout    = 600

  values = [yamlencode({
    clusterName    = var.cluster_name
    region         = var.region
    vpcId          = var.vpc_id
    serviceAccount = { create = true, name = "aws-load-balancer-controller" }
  })]

  depends_on = [aws_eks_pod_identity_association.alb_controller]
}

# ---- ExternalDNS: writes a DNS record for each Ingress host into ONE Route 53 zone ----
# Off unless dns_zone_id is set. The role can change records in that single zone only, and the controller runs in
# upsert-only mode, so it can create and update records but never delete one.
locals {
  external_dns = var.dns_zone_id != "" ? 1 : 0
}

resource "aws_iam_role" "external_dns" {
  count              = local.external_dns
  name               = "${var.name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "external_dns" {
  #checkov:skip=CKV_AWS_356:route53:ListHostedZones and ListResourceRecordSets do not support resource-level permissions; writes are scoped to one zone above
  count = local.external_dns

  statement {
    sid       = "ChangeRecordsInOneZone"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${var.dns_zone_id}"]
  }

  statement {
    sid       = "ListZonesAndRecords"
    actions   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:ListTagsForResource"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "external_dns" {
  count  = local.external_dns
  name   = "external-dns"
  role   = aws_iam_role.external_dns[0].id
  policy = data.aws_iam_policy_document.external_dns[0].json
}

resource "aws_eks_pod_identity_association" "external_dns" {
  count           = local.external_dns
  cluster_name    = var.cluster_name
  namespace       = "external-dns"
  service_account = "external-dns"
  role_arn        = aws_iam_role.external_dns[0].arn
  tags            = var.tags
}

resource "helm_release" "external_dns" {
  count            = local.external_dns
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = var.chart_versions["external-dns"]
  namespace        = "external-dns"
  create_namespace = true
  timeout          = 600

  values = [yamlencode({
    provider       = { name = "aws" }
    sources        = ["ingress"]
    policy         = "upsert-only"
    registry       = "txt"
    txtOwnerId     = "${var.name}-${var.cluster_name}"
    domainFilters  = [var.dns_zone_name]
    serviceAccount = { create = true, name = "external-dns" }
    extraArgs      = ["--aws-zone-type=public"]
  })]

  # The load balancer controller's webhook sees every new Service: install it first.
  depends_on = [helm_release.alb_controller, aws_eks_pod_identity_association.external_dns]
}

# ---- Kyverno: read-only registry access so image-verification policies can fetch attestations ----
# Only the admission controller (where image verification runs) gets an identity. The role can read image metadata and
# layers of the school-* repositories and nothing else; it cannot push, delete or touch other repositories.
locals {
  kyverno_ecr = var.enable_kyverno_ecr_access ? 1 : 0
}

data "aws_caller_identity" "kyverno" {
  count = local.kyverno_ecr
}

resource "aws_iam_role" "kyverno_ecr" {
  count              = local.kyverno_ecr
  name               = "${var.name}-kyverno-ecr"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "kyverno_ecr" {
  #checkov:skip=CKV_AWS_356:ecr:GetAuthorizationToken does not support resource-level permissions; image reads are scoped to the school-* repositories below
  count = local.kyverno_ecr

  statement {
    sid       = "RegistryLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ReadSchoolImages"
    actions = [
      "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability",
      "ecr:DescribeImages", "ecr:ListImages",
    ]
    resources = ["arn:aws:ecr:${var.region}:${data.aws_caller_identity.kyverno[0].account_id}:repository/school-*"]
  }
}

resource "aws_iam_role_policy" "kyverno_ecr" {
  count  = local.kyverno_ecr
  name   = "kyverno-ecr-read"
  role   = aws_iam_role.kyverno_ecr[0].id
  policy = data.aws_iam_policy_document.kyverno_ecr[0].json
}

resource "aws_eks_pod_identity_association" "kyverno_ecr" {
  count           = local.kyverno_ecr
  cluster_name    = var.cluster_name
  namespace       = "kyverno"
  service_account = "kyverno-admission-controller"
  role_arn        = aws_iam_role.kyverno_ecr[0].arn
  tags            = var.tags
}

# ---- External Secrets Operator: Secrets Manager -> Kubernetes Secrets ----
# Its IAM role and Pod Identity association live in modules/secrets (namespace/service account must match).
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_versions["external-secrets"]
  namespace        = "external-secrets"
  create_namespace = true
  timeout          = 600

  values = [yamlencode({
    installCRDs    = true
    serviceAccount = { create = true, name = "external-secrets" }
  })]

  # The ALB controller's mutating webhook sees every new Service: install it first or the others race it.
  depends_on = [helm_release.alb_controller]
}

# ---- Argo CD and Argo Rollouts ----
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_versions["argo-cd"]
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600

  # Not exposed publicly: reach it with `kubectl port-forward` or through an internal ingress.
  values = [yamlencode({
    configs = { params = { "server.insecure" = false } }
  })]

  # The ALB controller's mutating webhook sees every new Service: install it first or the others race it.
  depends_on = [helm_release.alb_controller]
}

resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  version          = var.chart_versions["argo-rollouts"]
  namespace        = "argo-rollouts"
  create_namespace = true
  timeout          = 600

  values = [yamlencode({
    dashboard = { enabled = false }
  })]

  # The ALB controller's mutating webhook sees every new Service: install it first or the others race it.
  depends_on = [helm_release.alb_controller]
}

# ---- Prometheus, Alertmanager, Grafana ----
resource "helm_release" "prometheus_stack" {
  count            = var.enable_prometheus_stack ? 1 : 0
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_versions["kube-prometheus-stack"]
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 900

  values = [yamlencode({
    prometheus = { prometheusSpec = {
      retention = "7d"
      # Pick up monitors and rules from Git (school-gitops), not only those labelled with this Helm release.
      serviceMonitorSelectorNilUsesHelmValues = false
      podMonitorSelectorNilUsesHelmValues     = false
      ruleSelectorNilUsesHelmValues           = false
    } }
    alertmanager = { alertmanagerSpec = {
      # Alert routing lives in Git as AlertmanagerConfig objects. None = their routes see alerts from every namespace.
      alertmanagerConfigSelector          = {}
      alertmanagerConfigNamespaceSelector = {}
      alertmanagerConfigMatcherStrategy   = { type = "None" }
    } }
    grafana = {
      enabled = true
      # Load dashboards from ConfigMaps labelled grafana_dashboard=1 in any namespace.
      sidecar = { dashboards = { enabled = true, label = "grafana_dashboard", searchNamespace = "ALL" } }
    }
  })]

  # The ALB controller's mutating webhook sees every new Service: install it first or the others race it.
  depends_on = [helm_release.alb_controller]
}
