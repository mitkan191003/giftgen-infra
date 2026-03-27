# Migration To Stack Layout

This guide is for migrating an already-running `infra/environments/dev/...`
deployment to the stack-based layout:

- `infra/stacks/shared-delivery`
- `infra/stacks/core`
- `infra/stacks/bootstrap`
- `infra/stacks/gitops`

## Why The Migration Needs Care

The old dev layout mixed:

- runtime infrastructure
- environment-specific ECR repositories
- backend delivery resources

The new layout separates them:

- runtime stays in `core` / `bootstrap` / `gitops`
- shared ECR and delivery move to `shared-delivery`

That means a direct `dev core apply` from the new layout can destroy the old
env-scoped ECR repositories before the cluster is using the new shared ones.

Do not start by applying the new `dev core` stack.

## Safe Order

1. Bring up `shared-delivery` first.
2. Populate the new shared ECR repos with images.
3. Point `dev gitops` at the shared repos and redeploy.
4. Verify `dev` is healthy.
5. Only then apply the refactored `dev core` stack so the old env-scoped ECR
   repos are removed.

## Detailed Steps

### 1. Apply Shared Delivery

```bash
./infra/bin/tf shared-delivery init
./infra/bin/tf shared-delivery plan
./infra/bin/tf shared-delivery apply
```

This creates the shared ECR repos and delivery pipeline state.

### 2. Build Or Trigger Images Into Shared ECR

Make sure the new shared repositories actually contain the backend images before
switching ArgoCD to them.

If the delivery pipeline is wired to the `dev` branch, push a backend
commit to `dev` or manually re-run the `dev` pipeline so the shared repos
receive images.

### 3. Repoint Dev GitOps To Shared Delivery State

Your `infra/envs/dev/gitops.tfvars` should point `shared_delivery_state_key` at:

```hcl
shared_delivery_state_key = "environments/shared/delivery/terraform.tfstate"
```

Then:

```bash
./infra/bin/tf dev gitops init
./infra/bin/tf dev gitops plan
./infra/bin/tf dev gitops apply
```

At this point, ArgoCD should be using image repositories from shared delivery.

### 4. Verify Dev Health

Confirm:

- ArgoCD app is synced and healthy
- API and worker are running from the shared image repos
- generation still works end to end

Do not continue until this is true.

### 5. Apply The Refactored Dev Core Stack

Once the cluster is no longer relying on the old env-scoped ECR repos:

```bash
./infra/bin/tf dev core init
./infra/bin/tf dev core plan
./infra/bin/tf dev core apply
```

At this point, destroying the old env-scoped ECR repos is expected.

### 6. Re-run Bootstrap If Needed

If your `dev bootstrap` stack changed at the same time:

```bash
./infra/bin/tf dev bootstrap init
./infra/bin/tf dev bootstrap plan
./infra/bin/tf dev bootstrap apply
```

## Production

Production does not need the legacy-layout migration if you never created it
under `infra/environments/...`.

Bring up prod directly with the new stack layout:

```bash
./infra/bin/tf prod core init
./infra/bin/tf prod core apply
./infra/bin/tf prod bootstrap init
./infra/bin/tf prod bootstrap apply
./infra/bin/tf prod gitops init
./infra/bin/tf prod gitops apply
```
