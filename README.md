# GiftGen Infrastructure

GiftGen Infrastructure provisions and operates the platform that the GiftGen application runs on.

This repository contains the Terraform code for the shared delivery pipeline and the per-environment runtime stacks that power the frontend and backend applications. It is responsible for the pieces you would expect around a production application platform: networking, Kubernetes, databases, storage, authentication, certificates, DNS, observability, and deployment plumbing.

## Related Repositories

- [giftgen-backend](https://github.com/mitkan191003/giftgen-backend) for the API, worker, Helm chart, and container build inputs
- [giftgen-frontend](https://github.com/mitkan191003/giftgen-frontend) for the user-facing Next.js application deployed separately on Vercel

## Role In The Architecture

This repository is responsible for the platform layer of the project.

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

The Terraform code is split into reusable stacks:

- `stacks/shared-delivery`
  - shared ECR repositories, CodeConnections, CodePipeline, and CodeBuild
- `stacks/core`
  - foundational AWS resources for an environment
- `stacks/bootstrap`
  - cluster services such as ArgoCD, ExternalDNS, External Secrets, and observability
- `stacks/gitops`
  - GitOps resources that depend on the bootstrap layer
- `envs/shared`
  - configuration for shared delivery
- `envs/dev`
  - development environment configuration
- `envs/prod`
  - production environment configuration
- `bin/tf`
  - a small wrapper for running Terraform against this stack layout

## Environments

The repository manages two long-lived runtime environments:

- `dev`
- `prod`

They use the same overall shape, but they remain isolated through their own:

- state
- DNS names
- Cognito pools and clients
- secrets
- runtime resources

## Running The Terraform Workflow

### Requirements

- Terraform
- AWS credentials with access to the target account
- access to the Cloudflare zone used by the project

### Basic Flow

The usual sequence is:

1. create or configure remote state
2. apply shared delivery
3. apply an environment’s `core`
4. apply that environment’s `bootstrap`
5. apply that environment’s `gitops`

From the root of this repository, the wrapper keeps the commands consistent:

```bash
./bin/tf shared-delivery plan
./bin/tf dev core plan
./bin/tf dev bootstrap plan
./bin/tf dev gitops plan
```

The same pattern applies to `prod`.

## Delivery Model

The delivery model is branch-based:

- the backend `dev` branch feeds the development deployment path
- the backend `main` branch feeds the production deployment path

Backend images are built in the shared delivery stack and then deployed into the appropriate environment through ArgoCD.

## Further Reading

- [docs/architecture.md](docs/architecture.md)
- [docs/migration-to-stacks.md](docs/migration-to-stacks.md)
