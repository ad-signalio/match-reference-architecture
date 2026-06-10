# secrets-configuration / eso-support (GCP)

ESO-based secrets configuration for GCP — the counterpart to `../ascp-support`
(AWS). Syncs GCP Secret Manager secrets into native Kubernetes Secrets via
[External Secrets Operator](https://external-secrets.io/), authenticated with
GKE Workload Identity. Produces the **same Kubernetes Secrets** (names + keys) as
`ascp-support`, so the Match application deployment is identical on AWS and GCP.

## Prerequisites

1. **ESO operator installed** in the cluster — done separately via the
   `tf-dt-external-secrets` Terraform module (sc-22517), not this chart.
2. **Workload Identity GSA** with `roles/secretmanager.secretAccessor`, bound to
   this chart's ServiceAccount — done in Terraform via `tf-dt-workload-identity`
   (sc-22516), `use_existing_k8s_sa = true` against `serviceAccount.name`. Set the
   GSA email in `serviceAccount.gcpServiceAccount` for the KSA annotation.
3. **The source secrets exist** in GCP Secret Manager:
   - Cloud SQL (`tf-dt-cloud-sql`) and Memorystore (`tf-dt-memorystore`) write theirs.
   - API + owning-user secrets: `tf-dt-application-secrets` (sc-22740).
   - `match-docker-secret` + `match-honeybadger-secret`: created manually (see the
     top-level README's GCP secrets section).

## What it creates

- A namespaced **`SecretStore`** (`gcpsm` provider + Workload Identity auth).
- A **`ServiceAccount`** carrying the `iam.gke.io/gcp-service-account` annotation.
- **`ExternalSecret`s** producing: `match-postgres-credentials`, `match-api-secrets`,
  `match-owning-user-credentials`, `<clusterName>-redis`, `dockerconfig`,
  `honeybadger-api-key`, and (optional) `smtp-secrets`.

## Open reconciliation points (flagged in templates)

- **Redis keys:** the app's k8s Secret uses `url` / `elasticache_url` / `endpoint`
  (AWS-branded). The GCP Memorystore secret has `host`/`port`/`auth`/`url`, so we map
  `url<-url`, `endpoint<-host`, `elasticache_url<-url`. Confirm against what the app reads.
- **Cloud SQL `db_name`:** GCP secret key is `dbname`; remapped to the app's `db_name`.

Replace the placeholder values in `values.yaml` (project, cluster, secret names,
GSA email) before installing.
