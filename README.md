# school-infra

Repo 3 of 3: Terraform / OpenTofu infrastructure. Validate-only in the learning repository: nothing here is applied without an explicit decision.

| Path | What |
|---|---|
| `modules/vpc` | 3 AZ, public / private / data subnets, NAT, S3 + interface VPC endpoints, flow logs |
| `modules/eks` | EKS control plane, managed node group, IRSA provider, Pod Identity agent, access entries, KMS |
| `modules/rds` | PostgreSQL, Multi-AZ option, KMS, RDS-managed master secret, force-SSL parameter group |
| `modules/secrets` | App secret in Secrets Manager, External Secrets role via Pod Identity |
| `modules/observability` | Alert topic, log group, RDS alarms |
| `modules/ecr`, `modules/iam-oidc-github` | Image registry and GitHub OIDC roles (modules 07, 08) |
| `modules/platform` | Composition of the above for one environment |
| `modules/argocd-bootstrap` | Helm: ALB controller, External Secrets, Argo CD, Argo Rollouts, kube-prometheus-stack |
| `bootstrap/` | `state` (S3 remote state), `ci-trust` (ECR + OIDC), `github-rulesets` (branch protection as code) |
| `live/{dev,staging,regulated}` | Per-environment root modules, each with its own state |
| `policies/` | Custom Checkov policies and Conftest (Rego) plan checks |

```bash
make infra-check     # fmt + validate every root module   (from the repository root)
make policy-check    # Checkov, tflint, Conftest, plan-time policy tests (needs docker)
```

## Cost estimate on pull requests

The `plan` job prices the real plan (`plan.json`) with Infracost and comments one table per environment (dev, staging) on the pull request. It is optional: it needs the repository secret `INFRACOST_API_KEY` (a free key from infracost.io) and the repository variable `INFRACOST_ENABLED=true`; without them the two steps are skipped. The steps use `continue-on-error`, so a pricing outage never blocks a pull request. Only price-related attributes (resource types, sizes, region) go to Infracost.
