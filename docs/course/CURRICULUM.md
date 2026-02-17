# Production-Grade Kubernetes with Guardrails & AI-Assisted SRE

## Approved Course Structure (13 Chapters)

1. **Production Mindset & Guardrails**
- Kubernetes != dev playground
- alert fatigue, blast radius, environment separation
- AI as read-only assistant

2. **Infrastructure as Code (IaC)**
- Terraform modules and structure
- remote state, IAM/RBAC, version pinning, drift detection, safe destroy
- **Lab:** build production-ready cluster

3. **Secrets Management (SOPS)**
- encrypted secrets with SOPS + age
- Flux + SOPS integration
- key rotation strategy
- **Lab:** encrypted secret -> deploy -> decrypt via Flux

4. **GitOps & Version Promotion**
- Flux architecture, HelmRelease/Kustomize overlays
- dev -> stage -> prod promotion (no rebuild), rollback, immutable tags
- **Lab:** real promotion workflow

5. **Network Policies (Production Isolation)**
- default deny, namespace isolation, ingress/egress controls, DNS allow patterns
- blocked traffic debugging
- **Lab:** break traffic and analyze

6. **Security Context & Pod Hardening**
- runAsNonRoot, readOnlyRootFilesystem, fsGroup, dropped capabilities
- privileged pod risks, Pod Security Standards
- **Lab:** permission failure recovery without root

7. **Resource Management & QoS**
- requests vs limits, QoS classes, OOMKilled behavior, node pressure
- overcommit and HPA interaction
- **Lab:** OOM simulation and root cause analysis

8. **Availability Engineering (HPA + PDB)**
- HPA mechanics, ScalingLimited, PDB, rolling updates, node drain
- HPA/PDB/rollout interaction
- **Lab:** drain node and analyze disruption

9. **Observability**
- metrics, logging, tracing, SLO/SLI, signal vs noise
- **Lab:** baseline monitoring stack

10. **Backup & Restore Basics**
- PVC snapshots, DB dumps, object storage backups
- restore simulation and verification
- **Lab:** backup -> restore -> validation

11. **Controlled Chaos**
- controlled failure engineering (OOM, rollout break, network isolation, PVC full, cert expiry, backup job failure, node drain)
- **Lab:** controlled breakage and behavior analysis

12. **AI-Assisted SRE Guardian**
- operator/watchers/scanners, context collectors, structured LLM JSON output
- escalation logic, incident store, cost control, redaction, confidence calibration
- **Lab:** guardian analyzes chaos scenarios

13. **24/7 Production SRE**
- on-call mindset, incident lifecycle, recurring-problem analysis
- blameless postmortems, continuous hardening
- why AI should not auto-fix production

## Learning Outcome

By the end of the course, learners can:
- build and operate a production-grade Kubernetes platform
- promote versions safely across environments
- enforce security and isolation guardrails
- manage resource behavior under pressure
- implement backup/restore practices
- run controlled chaos experiments safely
- use AI as a guardrail layer (not an autonomous executor)
- maintain 24/7 production stability patterns

## Pending Product Decisions

1. Final duration estimate in hours.
2. Target level: mid vs senior.
3. Exact lab scope per chapter.
4. Opening and closing narrative design for stronger course impact.
