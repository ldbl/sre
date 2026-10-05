# k8s-ai-monitor (the Guardian)

Deploys `k8s-ai-monitor` in namespace `observability`: every signal becomes one incident, one message.

## What It Does

- Receives the Prometheus alerts Alertmanager routes to it - all but `Watchdog` and `InfoInhibitor`
  (`alertmanager-guardian.yaml`, `POST /alertmanager`; a `resolved` alert closes its incident). The
  alert's own severity is final.
- Watches Warning events, Flux stalls and runs its own scanners (pods, nodes, HPA, PVC, certificates,
  endpoints, CloudNativePG backups).
- Deduplicates and escalates in SQLite, collects context, redacts secrets, asks the LLM (production
  namespace only - develop and staging are posted without an LLM call) and posts to Slack.
- Only reads (`clusterrole.yaml`) and has **no** access to Secrets: a cluster-wide read would expose
  `flux-system/sops-age` and every password to a component that processes alerts, logs and LLM output.
  Backup state comes from the CNPG `Cluster` status, TLS state from the cert-manager `Certificate`.

## Required Secret: `k8s-ai-monitor-secrets`

`internal-token` is required (the pod does not start without it): it guards every HTTP route but
`/healthz`, and Alertmanager sends it as a Bearer token. The LLM key and the Slack webhooks are optional
(without them nothing is analysed or posted - incidents are still tracked).

- **kind** (`local_profile = true`): Terraform creates the Secret - a random `internal-token` and the key
  from `guardian_llm_api_key` in `terraform.tfvars` (git-ignored). See `docs/local-dev.md`.
- **Hetzner**: copy `flux/secrets/observability/k8s-ai-monitor-secrets.yaml.example` to
  `k8s-ai-monitor-secrets.yaml`, fill it, encrypt it with SOPS and uncomment it in
  `flux/secrets/observability/kustomization.yaml`.

### Rotating `internal-token`

The Deployment reads the token into an env var at start, so a new Secret value reaches the pod only on
restart (Alertmanager picks it up by itself):

1. Change the Secret - Hetzner: edit and re-encrypt the SOPS file, commit; kind: `terraform apply
   -replace='random_password.guardian_internal_token[0]'`.
2. Wait until it is applied (`flux get kustomizations secrets-observability` on Hetzner).
3. `kubectl -n observability rollout restart deployment/k8s-ai-monitor` - until then Alertmanager's
   calls get 403.

## Runtime Endpoints

Service: `k8s-ai-monitor.observability.svc.cluster.local:8080`. All but `/healthz` need
`Authorization: Bearer <internal-token>` (or `X-Internal-Token`):

- health: `GET /healthz`
- incidents: `GET /incidents`, `GET /incidents/{id}`
- state: `GET /state`; reports: `GET /reports`; LLM cost: `GET /llm-usage?hours=24`
