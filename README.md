# GiftGen Infra

Terraform for the AWS platform that supports the frontend and backend.

## Structure

- `bootstrap/`
  - Creates the Terraform state bucket
- `environments/dev/`
  - Core AWS resources, Cloudflare DNS, and ACM validation wiring for the dev environment
- `environments/dev/bootstrap/`
  - In-cluster bootstrap that depends on the core environment state
- `environments/dev/gitops/`
  - CRD-backed GitOps resources that depend on the core and bootstrap state
- `modules/core_platform/`
  - VPC, EKS, RDS, S3, SQS, ECR, Cognito, Cloudflare DNS, and supporting resources
- `modules/cluster_bootstrap/`
  - ArgoCD installation, namespaces, runtime IRSA, ALB controller, ExternalDNS, and External Secrets
- `modules/cluster_gitops/`
  - ClusterSecretStore, ExternalSecrets, ArgoCD AppProject, and ArgoCD Application resources

## Why Three Environment Phases

Trying to create EKS and immediately use the Kubernetes, Helm, and CRD-backed manifest resources in the same root module usually leads to unstable applies. This repo avoids that by splitting:

1. core infrastructure
2. cluster bootstrap
3. gitops manifests

That still satisfies the “no kubectl bootstrap steps” requirement while keeping Terraform predictable.

Cleanup is no longer modeled as a Terraform-managed EventBridge or Lambda path. The intended scheduled cleanup path is an ArgoCD-managed Kubernetes `CronJob` that lives in the backend Helm release.

## Intended Apply Order

1. `infra/bootstrap`
2. `infra/environments/dev`
3. `infra/environments/dev/bootstrap`
4. `infra/environments/dev/gitops`

Staging and prod should follow the same pattern after dev is stable.
