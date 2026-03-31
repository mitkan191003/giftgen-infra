# Infrastructure Architecture

## Overview

The infrastructure repository provisions and operates the AWS platform for GiftGen.

It manages:

- networking
- compute
- storage
- authentication
- public DNS and certificates
- GitOps bootstrap
- image delivery
- observability

The platform is split into shared delivery infrastructure and per-environment runtime infrastructure.

## Environments

The repository manages two long-lived environments:

- `dev`
- `prod`

They share the same general platform shape and module layout, but use separate state, secrets, hostnames, Cognito configuration, and runtime resources.

Public hostnames are:

- dev frontend: `dev.giftgen-dev.mithrak.com`
- dev API: `api.giftgen-dev.mithrak.com`
- dev ArgoCD: `argocd.giftgen-dev.mithrak.com`
- prod frontend: `giftgen.mithrak.com`
- prod API: `api-giftgen.mithrak.com`
- prod ArgoCD: `argocd-giftgen.mithrak.com`

## Stack Layout

Terraform is organized into reusable stacks:

```text
infra/
  stacks/
    shared-delivery/
    core/
    bootstrap/
    gitops/
  envs/
    shared/
    dev/
    prod/
```

### `shared-delivery`

Shared delivery owns the build and deployment path that is not specific to one runtime environment:

- shared ECR repositories
- CodeConnections
- CodePipeline
- CodeBuild projects

### `core`

The core stack owns the foundational AWS resources for an environment:

- VPC and subnets
- EKS
- RDS
- S3
- SQS
- Cognito
- Secrets Manager secrets
- Cloudflare-managed DNS records
- ACM certificates

### `bootstrap`

The bootstrap stack installs and configures cluster-level services:

- ArgoCD
- AWS Load Balancer Controller
- External Secrets
- ExternalDNS
- IAM roles for service accounts
- CloudWatch observability baseline

### `gitops`

The GitOps stack creates the CRD-backed resources that depend on bootstrap:

- `ClusterSecretStore`
- external secret manifests
- ArgoCD project and application resources

## Delivery Model

Backend image delivery is branch-based:

- the `dev` pipeline watches the `dev` branch
- the `prod` pipeline watches the `main` branch

Images are built into shared ECR repositories and then deployed into the target environment through ArgoCD.

## Runtime Model

The runtime platform uses:

- EKS for application workloads
- Helm for packaging
- ArgoCD for deployment
- RDS for relational data
- S3 for generated assets and observability artifacts
- Cognito for authentication
- Cloudflare for public DNS
- ACM for TLS certificates

## DNS And TLS

Cloudflare is the public DNS provider for the platform.

- frontend hostnames are CNAMEs to Vercel
- API and ArgoCD hostnames are managed through AWS load balancers and ExternalDNS
- ACM certificates are validated through Cloudflare DNS records

The API and ArgoCD hostnames are kept separate from the frontend hostnames so certificate validation and CAA behavior stay predictable.

## Observability

The observability baseline is AWS-first:

- CloudWatch Observability EKS add-on
- centralized container logs in CloudWatch Logs
- ALB access logs in S3
- CloudWatch dashboards and alarms
- CloudWatch Synthetics canaries

Optional Sentry configuration is supported in the application layer.

## Operational Defaults

The shared delivery stack retains the newest three images per repository.

The runtime stacks in `dev` and `prod` use the same general node and database shape unless environment-specific configuration changes are introduced in the corresponding `envs/` files.
