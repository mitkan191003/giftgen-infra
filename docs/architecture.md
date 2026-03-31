# Infra Architecture

## Core Decisions

### Two Real Environments

The platform now assumes only two long-lived environments:

- `dev`
- `prod`

There is no staging stack. PR review belongs in Vercel preview deployments, not in a separately managed Terraform environment.

Stable hostnames:

- dev frontend: `dev.giftgen-dev.mithrak.com`
- dev API: `api.giftgen-dev.mithrak.com`
- dev ArgoCD: `argocd.giftgen-dev.mithrak.com`
- prod frontend: `giftgen.mithrak.com`
- prod API: `api-giftgen.mithrak.com`
- prod ArgoCD: `argocd-giftgen.mithrak.com`

Do not place AWS-managed hosts under a frontend hostname that is itself a Vercel `CNAME`.

- `giftgen.mithrak.com` is the prod frontend `CNAME`, so prod API and ArgoCD must be siblings like `api-giftgen...` and `argocd-giftgen...`
- `dev.giftgen-dev.mithrak.com` is the dev frontend `CNAME`, so dev API and ArgoCD must be siblings like `api.giftgen-dev...` and `argocd.giftgen-dev...`

### Shared Build, Separate Runtime

Backend image build and publish are now modeled as a shared concern:

- shared ECR repositories
- CodeConnections
- CodePipeline
- CodeBuild image builds
- a reusable ArgoCD deploy CodeBuild project

Runtime remains environment-specific:

- `core`
- `bootstrap`
- `gitops`

This separates “build once” from “deploy many”.

### Terraform Layout

Terraform now uses shared stack code plus per-environment config:

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

This is more maintainable than copying `dev` folders into `prod`.

Promotion works like this:

1. change Terraform code once
2. apply to `dev`
3. validate
4. apply the same code to `prod`

If a change should remain `dev`-only for a while, gate it with environment-specific variables instead of cloning the Terraform root.

### Authentication

Use one Cognito user pool per deployed environment.

- dev auth is real Cognito auth, not a special local-only mode
- prod has its own isolated Cognito configuration
- Vercel preview URLs are not used as deployed auth callback URLs

### Public DNS And TLS

Cloudflare is the authoritative public DNS provider.

- frontend hostnames are Cloudflare `CNAME`s to Vercel
- ACM certificates are validated through Cloudflare DNS records
- ExternalDNS keeps dynamic ALB hostnames mapped to Cloudflare API records

Route 53 is not part of the public DNS path.

### Scheduled Cleanup

Cleanup runs as an ArgoCD-managed Kubernetes `CronJob` in the backend Helm release.

That keeps cleanup in the same image, deployment, and observability path as the rest of the app.

### Delivery And Promotion

The current delivery model is:

- one shared-delivery stack owns shared ECR and branch-specific pipelines
- the `dev` pipeline watches the `dev` branch and deploys dev ArgoCD
- the `prod` pipeline watches the `main` branch and deploys prod ArgoCD
- both images are tagged with the source commit SHA
- the deploy CodeBuild project is still reusable for manual resyncs or emergency redeploys

This keeps backend promotion aligned with a PR-based branch flow.

### Runtime GitOps

ArgoCD manages the runtime workloads:

- API deployment
- worker deployment
- cleanup `CronJob`
- migration `Job`
- ALB ingress

The GitOps Terraform root handles the CRD-backed resources that should not be mixed into the initial cluster bootstrap apply.

### Observability

The baseline remains AWS-first:

- CloudWatch Observability EKS add-on
- centralized container logs in CloudWatch Logs
- ALB access logs to S3
- CloudWatch dashboard and alarms
- CloudWatch Synthetics canary for the public API
- Sentry for frontend and backend exceptions

## What Is Included In The Current Scaffold

- state bucket bootstrap
- shared backend delivery stack
- runtime VPC, EKS, RDS, S3, SQS, Cognito
- Cloudflare DNS and ACM validation
- ArgoCD, AWS Load Balancer Controller, ExternalDNS, External Secrets
- CloudWatch observability baseline
- GitOps application bootstrap

## Current Practical Defaults

- dev defaults to `3 x t4g.small` nodes because the controller footprint plus CloudWatch add-on does not fit on two nodes
- prod example config uses stronger RDS settings: backups, Multi-AZ, and deletion protection
- shared delivery keeps the newest `3` images per repo by default

## What Still Needs Iteration Later

- making prod ArgoCD private instead of publicly reachable
- stronger Terraform apply automation and policy gates
- optional Git write-back for GitOps releases if you want fully Git-pinned env state instead of Argo runtime overrides
- richer tracing across frontend, API, worker, Modal, and OpenAI
