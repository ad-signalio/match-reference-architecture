# secrets-configuration

Optional secrets wiring for the Match Reference Architecture, split by cloud
secrets backend. This directory is a **folder of two charts** (not a chart itself):

- **[`ascp-support/`](./ascp-support)** — **AWS**: `SecretProviderClass` resources
  (EKS ASCP + the AWS Secrets Manager CSI driver) plus a secret-sync deployment.
  The original chart, unchanged.
- **[`eso-support/`](./eso-support)** — **GCP/AWS**: [External Secrets Operator](https://external-secrets.io/)
  + GCP Secret Manager, authenticated via GKE Workload Identity.

Both charts produce the **same Kubernetes Secrets** (names + keys), so the Match
application deployment is identical across clouds — only the secrets-backend
chart differs. Install the one matching your cloud; see each chart's README.

The ESO operator/controller itself is installed separately (Terraform
`tf-dt-external-secrets`), not by `eso-support`.
