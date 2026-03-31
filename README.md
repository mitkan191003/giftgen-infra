# GiftGen Infra

Terraform for the AWS platform, split into shared delivery and per-environment runtime stacks.

## Structure

- `bootstrap/`
  - one-time S3 remote-state bucket
- `stacks/shared-delivery/`
  - shared ECR, CodeConnections, CodePipeline, CodeBuild, and reusable Argo deploy project
- `stacks/core/`
  - VPC, EKS, RDS, S3, SQS, Cognito, DNS, ACM, and environment secrets
- `stacks/bootstrap/`
  - ArgoCD, AWS Load Balancer Controller, ExternalDNS, External Secrets, IRSA, and observability bootstrap
- `stacks/gitops/`
  - CRD-backed GitOps resources and the ArgoCD application definition
- `envs/shared/`
  - shared delivery config
- `envs/dev/`
  - dev runtime config
- `envs/prod/`
  - prod runtime config
- `modules/`
  - reusable Terraform modules
- `bin/tf`
  - wrapper for stack/environment Terraform commands
  - isolates a separate `TF_DATA_DIR` per environment and stack so `dev` and `prod` do not reuse the same backend selection

## Why The Stacks Are Split

The runtime platform is intentionally split into:

1. `core`
2. `bootstrap`
3. `gitops`

That keeps EKS provisioning, Helm installs, and CRD-backed manifests out of the same apply, which makes Terraform far more predictable.

Shared delivery is separate because image build/publish should not live inside a single environment’s runtime state.

## Intended Apply Order

One-time:

1. `infra/bootstrap`

Shared:

2. `infra/stacks/shared-delivery`

Per environment:

3. `infra/stacks/core`
4. `infra/stacks/bootstrap`
5. `infra/stacks/gitops`

Use the wrapper:

```bash
./infra/bin/tf shared-delivery plan
./infra/bin/tf dev core plan
./infra/bin/tf prod bootstrap apply
```

## Promotion Model

- shared delivery builds backend images once and tags them with the source commit SHA
- `dev` branch deploys the dev ArgoCD app
- `main` branch deploys the prod ArgoCD app
- Terraform code is shared across environments; promotion happens by apply order and environment config, not by copying folders

Read [Promotion.md](/home/mithrak/giftgen/Promotion.md) for the full runtime promotion flow.

If you are migrating an already-running dev environment from the old layout,
read [infra/docs/migration-to-stacks.md](/home/mithrak/giftgen/infra/docs/migration-to-stacks.md)
before your first stack-based apply.
