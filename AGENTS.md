# Repository Guidelines

## Project Structure & Module Organization
- Treat the repo as the SRE control plane: keep IaC modules in `infra/terraform` and Kubernetes manifests in `infra/kubernetes`, with shared components under `infra/modules`.
- Place automation code in `src/`; mirror tests in `tests/<component>` and reusable helpers in `scripts/`.
- Maintain living documentation in `docs/` (architecture notes, runbooks) and commit only redacted samples in `config/examples/`; secrets stay in the vault.

## Build, Test, and Development Commands
- `make bootstrap`: install Terraform, Kubectl, pre-commit hooks, and any service-specific CLIs pinned in the Makefile.
- `make fmt`: wrap `terraform fmt`, `black`, and `shellcheck` to enforce formatting before commits.
- `make test`: execute unit and integration suites under `tests/`; expand the recipe as new services appear.
- `make plan`: run Terraform plans for every workspace; mirror this command in CI for parity.

## Coding Style & Naming Conventions
- Use 2 spaces for YAML/Terraform, 4 for Python; never commit tabs.
- Name Terraform modules `terraform-<domain>`, Kubernetes manifests `*-deployment.yaml`, Python files `snake_case.py`, and shell scripts in kebab-case.
- Register all formatters and linters in `.pre-commit-config.yaml` so contributors get the same checks locally and in CI.

## Testing Guidelines
- Favor `pytest` for Python automation, `bats` for shell utilities, and pair `terraform validate` with `terraform plan` in ephemeral workspaces.
- Follow the `tests/<component>/test_*.py` pattern and store reusable fixtures under `tests/fixtures/`.
- Hold ≥80% coverage for Python modules via `pytest --cov`; explain intentional gaps in `docs/testing.md`.

## Commit & Pull Request Guidelines
- Adopt Conventional Commit prefixes (`feat:`, `fix:`, `chore:`, `docs:`) with subjects ≤72 characters and wrapped bodies.
- Keep each commit focused, updating relevant docs, dashboards, and alerts alongside code.
- Pull requests must include a summary, linked issue or incident ID, Terraform plan or test output, and screenshots for dashboard tweaks; request review from the on-call peer.

## Security & Configuration Tips
- Store secrets exclusively in the managed vault referenced by `config/secrets.yaml`; commit templates or mock data instead.
- Run `make security-scan` (bundling `tfsec`, `trivy`, and future scanners) before merging, and schedule quarterly token rotations in `docs/security-calendar.md`.
