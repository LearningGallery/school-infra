# Ephemeral self-hosted runners (Actions Runner Controller) inside the cluster's private subnets:
# one pod per job, destroyed afterwards. Credentials for GitHub come from a Kubernetes Secret created
# out of band (External Secrets from Secrets Manager); no credential appears in Terraform.
resource "helm_release" "arc_controller" {
  name             = "arc"
  chart            = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"
  version          = "0.15.1"
  namespace        = "arc-systems"
  create_namespace = true

  depends_on = [module.bootstrap]
}

resource "helm_release" "arc_runners" {
  name             = "school-runners"
  chart            = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
  version          = "0.15.1"
  namespace        = "arc-runners"
  create_namespace = true

  values = [yamlencode({
    githubConfigUrl    = var.github_config_url
    githubConfigSecret = var.runner_secret_name
    minRunners         = 0 # scale to zero when idle
    maxRunners         = 10
  })]

  depends_on = [helm_release.arc_controller]
}
