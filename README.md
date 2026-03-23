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
- `modules/backend_delivery/`
  - CodeConnections, CodePipeline, CodeBuild, artifact storage, and ECR lifecycle policy resources for backend image delivery
- `modules/cluster_bootstrap/`
  - ArgoCD installation, namespaces, runtime IRSA, ALB controller, ExternalDNS, and External Secrets
- `modules/cluster_gitops/`
  - ClusterSecretStore, ExternalSecrets, ArgoCD AppProject, and ArgoCD Application resources
- `modules/observability/`
  - CloudWatch Observability add-on, ALB access-log bucket, dashboard, alarms, SNS topic, and public API canary

## Why Three Environment Phases

Trying to create EKS and immediately use the Kubernetes, Helm, and CRD-backed manifest resources in the same root module usually leads to unstable applies. This repo avoids that by splitting:

1. core infrastructure
2. cluster bootstrap
3. gitops manifests

That still satisfies the “no kubectl bootstrap steps” requirement while keeping Terraform predictable.

Cleanup is no longer modeled as a Terraform-managed EventBridge or Lambda path. The intended scheduled cleanup path is an ArgoCD-managed Kubernetes `CronJob` that lives in the backend Helm release.

Backend image delivery can now also be managed in AWS:

1. GitHub source via CodeConnections
2. image build and ECR push via CodeBuild, tagged with the source commit SHA
3. optional second CodeBuild stage that updates ArgoCD to that same commit SHA and forces a sync
4. GitOps deployment via ArgoCD using the repo commit and Helm parameter overrides selected by the pipeline

Manual version bump commits are no longer required for the dev delivery path. Automatic Git write-back is still intentionally out of scope.

## Intended Apply Order

1. `infra/bootstrap`
2. `infra/environments/dev`
3. `infra/environments/dev/bootstrap`
4. `infra/environments/dev/gitops`

Staging and prod should follow the same pattern after dev is stable.
