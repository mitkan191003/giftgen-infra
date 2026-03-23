# Infra Architecture

## Core Decisions

### Environment Separation

Treat dev, staging, and prod as real environments with stable hostnames instead of relying on raw Vercel preview URLs.

Recommended hostname layout:

- Prod frontend: `giftgen.mithrak.com`
- Dev frontend: `dev.giftgen.mithrak.com`
- Staging frontend: `staging.giftgen.mithrak.com`
- Prod API: `api.giftgen.mithrak.com`
- Dev API: `api-dev.giftgen.mithrak.com`
- Staging API: `api-staging.giftgen.mithrak.com`
- Prod ArgoCD: `argocd.giftgen.mithrak.com`
- Dev ArgoCD: `argocd-dev.giftgen.mithrak.com`
- Staging ArgoCD: `argocd-staging.giftgen.mithrak.com`

Vercel preview deployments still matter for PR review, but they are not the source of truth for deployed environments because Cognito callback URLs need to be exact and stable.

Do not hang AWS-managed endpoints off a frontend hostname that is itself a Vercel `CNAME`. A name like `argocd.dev.giftgen.mithrak.com` inherits the `dev.giftgen.mithrak.com` branch, which is delegated to Vercel. Use sibling labels like `argocd-dev.giftgen.mithrak.com` and `api-dev.giftgen.mithrak.com` instead.

If a single Vercel project cannot provide enough stable non-production environments on the chosen plan, use multiple Vercel projects. The infrastructure requirement is stable hostnames per environment, not a single Vercel project.

### Authentication

Use Amazon Cognito User Pools with the authorization code flow and PKCE. Each deployed environment should have its own Cognito configuration and stable frontend origin.

### Public DNS And TLS

Use Cloudflare as the authoritative public DNS provider and manage the required records through Terraform.

- Frontend hostnames are Cloudflare `CNAME` records that point at Vercel.
- API certificates are ACM certificates validated through Cloudflare-managed DNS validation records.
- Route 53 is no longer part of the public DNS path.

This keeps DNS and certificates aligned with the user’s actual DNS provider instead of splitting authority between Cloudflare and Route 53.

For Kubernetes-created AWS load balancers, the practical DNS automation path is ExternalDNS with the Cloudflare provider. Terraform creates the zone-level prerequisites and secret containers; in-cluster controllers keep dynamic ALB hostnames mapped to stable Cloudflare records.

### Scheduled Cleanup

Scheduled cleanup should run as an in-cluster Kubernetes `CronJob` managed by ArgoCD as part of the backend release.

This is a better fit than `EventBridge Scheduler -> Lambda -> Kubernetes Job` because:

- cleanup stays in the same deployment and image management flow as the rest of the workloads
- image updates can follow normal GitOps instead of Terraform variables
- there is no separate Lambda IAM and EKS RBAC bridge to bootstrap

### Backend Delivery

Use AWS CodeConnections + CodePipeline + CodeBuild for backend image publishing.

The intended release flow is:

- CodePipeline watches the private backend repo branch
- the source action exposes the Git commit SHA
- CodeBuild builds the API and worker images and tags them with that same commit SHA
- optionally, a second CodeBuild stage authenticates to ArgoCD, sets the `Application` revision and Helm image-tag overrides to that same commit SHA, and waits for the sync to finish

This keeps image publishing in AWS and avoids manual version bump commits for the dev release path.

Automatic Git write-back is still possible later, but it is not part of the current design because the current delivery path no longer needs version bump commits to release dev.

### TLS And Ingress

Provision ACM certificates in Terraform for the backend API. Avoid cert-manager for the first production pass so there is no separate in-cluster certificate IAM story to bootstrap manually.

### Observability

Use an AWS-first observability baseline:

- Amazon CloudWatch Observability EKS add-on for cluster logs and baseline EKS telemetry
- CloudWatch Logs for centralized application and cluster logs
- CloudWatch Embedded Metric Format for application metrics emitted by the API, worker, and cleanup job
- CloudWatch dashboard and alarms for service, RDS, and S3 views
- CloudWatch Synthetics canary for the public API hostname
- ALB access logs written to S3
- Sentry for frontend and backend exception visibility

This keeps the first production pass manageable and directly aligned with the spec. Prometheus and Grafana can still be layered on later if stronger Kubernetes-native querying becomes necessary.

## What Is Included In This Scaffold

- bootstrap state bucket
- runtime VPC, EKS, RDS, S3, SQS, ECR, Cognito
- optional CodeConnections, CodePipeline, CodeBuild, and ECR lifecycle policy resources for backend image delivery
- optional ArgoCD refresh stage inside the backend delivery pipeline
- CloudWatch Observability EKS add-on
- CloudWatch dashboard, alarms, SNS topic, and API uptime canary
- ALB access-log bucket
- Cloudflare frontend DNS record management
- ACM certificate request and Cloudflare DNS validation wiring for the API and ArgoCD hostnames
- ArgoCD install and namespace bootstrap
- backend runtime IRSA for Secrets Manager and S3 access
- AWS Load Balancer Controller
- External Secrets
- ExternalDNS with Cloudflare
- a separate GitOps Terraform phase for `ClusterSecretStore`, `ExternalSecret`, ArgoCD `AppProject`, and ArgoCD `Application`

Current default cost and compatibility posture:

- The default EKS node group is `t4g.small` on ARM64 Amazon Linux 2023 to fit lower-cost development accounts.
- The dev environment overrides that generic default to `3 x t4g.small` because the current controller set plus the CloudWatch Observability add-on does not fit on two 11-pod nodes.
- The default RDS backup retention period is `0` so database creation succeeds on constrained AWS account plans.
- Existing Cloudflare frontend and ACM validation records still need to be absent or imported into Terraform if they were created outside Terraform.

## What Still Needs A Follow-Up Infra Pass

- non-GitHub private repo credential options if GitHub App auth is not the chosen model
- Prometheus and Grafana if CloudWatch dashboards and Logs Insights stop being sufficient
- richer distributed tracing across frontend, API, worker, and external providers
- staging and prod environments

## Reference Docs

- Terraform S3 backend: https://developer.hashicorp.com/terraform/language/backend/s3
- Cloudflare provider customization: https://developers.cloudflare.com/terraform/advanced-topics/provider-customization/
- Cloudflare DNS Terraform resource: https://developers.cloudflare.com/api/terraform/resources/dns/subresources/records/
- ACM DNS validation: https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html
- Cognito PKCE: https://docs.aws.amazon.com/cognito/latest/developerguide/using-pkce-in-authorization-code.html
- Cognito app client callback URL requirements: https://docs.aws.amazon.com/cognito/latest/developerguide/authorization-endpoint.html
- Vercel custom environments: https://vercel.com/docs/custom-environments
- Vercel access control: https://vercel.com/docs/security/access-control
- Kubernetes CronJob: https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
- Argo CD automated sync: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/
- CloudWatch Observability EKS add-on: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-EKS-addon.html
- CloudWatch Application Signals for EKS: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Signals-Enable-EKS.html
- ALB access logs: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
- CloudWatch Synthetics: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Synthetics_Canaries.html
