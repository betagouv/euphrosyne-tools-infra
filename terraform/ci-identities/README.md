# CI identities

User-assigned managed identities that GitHub Actions uses to reach Azure with OpenID Connect, without stored secrets. Each identity trusts a single GitHub environment of `betagouv/euphrosyne-tools-infra`:

| Identity | GitHub environment | Purpose |
| --- | --- | --- |
| `ci-staging` | `staging` | Apply on staging from `main` |
| `ci-staging-plan` | `staging-plan` | Plan staging for pull requests, no write access |
| `ci-prod-plan` | `production-plan` | Plan production from `main`, no write access |
| `ci-prod-apply` | `production` | Apply the reviewed production plan |

The environment protection rules (allowed branches, required reviewers) are what restrict each identity. Configure them in GitHub before granting any role.

This configuration is applied by a maintainer, never by CI. It only creates the identities and their federated credentials: a `Contributor` on `Euphrosyne_tfstate` can apply it.

## Apply

The state lives in its own `tfstate-ci` container, which CI identities must not be able to write. Create it once:

```bash
az storage container-rm create --resource-group Euphrosyne_tfstate --storage-account euphrosynetfstate --name tfstate-ci
```

Then, from this directory:

```bash
terraform init
terraform plan -out=ci-identities.tfplan
terraform apply ci-identities.tfplan
terraform output
```

The state holds no secret.

## Role assignments

Creating role assignments needs `Owner` or `User Access Administrator`, which maintainers do not have on these resource groups. Ask a subscription administrator to grant, using the `principal_ids` output:

| Identity | Role | Scope |
| --- | --- | --- |
| `ci-staging` | `Contributor` | resource group `Euphrosyne_staging` |
| `ci-staging` | `Storage Blob Data Contributor` | container `tfstate-staging` |
| `ci-staging-plan` | `Reader` | resource group `Euphrosyne_staging` |
| `ci-staging-plan` | `Storage Blob Data Reader` | container `tfstate-staging` |
| `ci-prod-plan` | `Reader` | resource group `Euphrosyne` |
| `ci-prod-plan` | `Storage Blob Data Reader` | container `tfstate-production` |
| `ci-prod-apply` | `Contributor` | resource group `Euphrosyne` |
| `ci-prod-apply` | `Storage Blob Data Contributor` | container `tfstate-production` |

Each environment state gets its own container, because data roles cannot be scoped below a container: `tfstate-staging` for `staging.tfstate` and `tfstate-production` for `production.tfstate`. Both states currently sit in the `tfstate` container and must be migrated before these roles are granted. No CI identity gets access to `tfstate-ci`.

`Reader` is not enough for a plan: refreshing the storage account, the web app and the Key Vault secret calls list actions (`listKeys`, app settings, secret `Get`). The plan identities will need a custom role adding those actions, defined once the pull request plans run.

Each identity that plans or applies must also be added to `key_vault_secret_manager_object_ids` in the matching tfvars file.
