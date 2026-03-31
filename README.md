# GiftGen Infrastructure

GiftGen Infrastructure provisions and operates the AWS side of the GiftGen platform.

This repository contains the Terraform code for the shared delivery pipeline and the per-environment runtime stacks that power the frontend and backend applications. It is responsible for the pieces you would expect around a production application platform: networking, Kubernetes, databases, storage, authentication, certificates, DNS, observability, and deployment plumbing.

## Related Repositories

- [giftgen-backend](https://github.com/mitkan191003/giftgen-backend): the API, worker, and Helm chart deployed into the cluster
- [giftgen-frontend](https://github.com/mitkan191003/giftgen-frontend): the Vercel-hosted Next.js application that talks to the backend

## Where This Repo Fits

The GiftGen architecture is split across three repositories:

- the frontend delivers the user experience
- the backend owns application logic and generation workflows
- this repository creates and wires together the platform those applications run on

That includes:

- VPC and networking
- EKS
- RDS
- S3
- Cognito
- Cloudflare-managed DNS records
- ACM certificates
- ArgoCD and supporting controllers
- CloudWatch-based observability
- shared image build and deployment infrastructure

## Repository Layout

The Terraform code is intentionally split into reusable stacks instead of duplicated environment folders:

- `stacks/shared-delivery`
  - shared ECR repositories, CodeConnections, CodePipeline, and CodeBuild
- `stacks/core`
  - foundational AWS resources for an environment
- `stacks/bootstrap`
  - cluster services such as ArgoCD, ExternalDNS, External Secrets, and observability
- `stacks/gitops`
  - GitOps resources that depend on CRDs installed during bootstrap
- `envs/shared`
  - configuration for shared delivery
- `envs/dev`
  - development environment configuration
- `envs/prod`
  - production environment configuration
- `bin/tf`
  - a wrapper around Terraform commands for the stack and environment layout used here

## Environment Model

The platform is built around two long-lived environments:

- `dev`
- `prod`

They are intended to be similar in shape, but isolated from one another by state, DNS, secrets, Cognito, and runtime resources.

## Getting Started

This repository assumes you already have:

- Terraform installed
- AWS credentials configured
- access to the target Cloudflare zone

The usual flow is:

1. bootstrap remote state
2. configure shared delivery
3. apply the environment stacks in order

The wrapper script keeps the command flow consistent:

```bash
./infra/bin/tf shared-delivery plan
./infra/bin/tf dev core plan
./infra/bin/tf dev bootstrap plan
./infra/bin/tf dev gitops plan
```

The same pattern applies to `prod`.

## Deployment Model

The delivery model is branch-based:

- the `dev` branch drives the development deployment path
- the `main` branch drives the production deployment path

Backend images are built in the shared delivery stack and then deployed into the appropriate environment through ArgoCD.

## Documentation

This repository still contains more operational detail than the other two, so the additional docs are worth reading if you plan to work on the platform itself:

- [docs/architecture.md](docs/architecture.md)
- [docs/migration-to-stacks.md](docs/migration-to-stacks.md)
