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
}
