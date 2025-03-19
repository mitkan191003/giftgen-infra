# GiftGen Infra

Terraform for the AWS platform that supports the frontend and backend.

## Structure

- `bootstrap/`
  - Creates the Terraform state bucket
- `environments/dev/`
  - Core AWS resources, Cloudflare DNS, and ACM validation wiring for the dev environment
- `environments/dev/bootstrap/`
  - In-cluster bootstrap that depends on the core environment state
- `modules/core_platform/`
  - VPC, EKS, RDS, S3, SQS, ECR, Cognito, Cloudflare DNS, and supporting resources
- `modules/cluster_bootstrap/`
  - ArgoCD installation and namespace bootstrap

## Why Two Environment Phases

Trying to create EKS and immediately use the Kubernetes and Helm providers in the same root module usually leads to unstable applies. This repo avoids that by splitting:

1. core infrastructure
2. cluster bootstrap

That still satisfies the “no kubectl bootstrap steps” requirement while keeping Terraform predictable.

Cleanup is no longer modeled as a Terraform-managed EventBridge or Lambda path. The intended scheduled cleanup path is an ArgoCD-managed Kubernetes `CronJob` that will live with the other application manifests.

## Intended Apply Order

1. `infra/bootstrap`
2. `infra/environments/dev`
3. `infra/environments/dev/bootstrap`

Staging and prod should follow the same pattern after dev is stable.
