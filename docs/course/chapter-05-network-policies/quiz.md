# Quiz: Chapter 05 (Network Policies)

## Questions

1. Why is `default deny` a safer starting point than allow-all networking?

2. What two policy types are usually set for full baseline isolation?

3. After applying default deny, DNS fails. What is the minimal next policy you should add?

4. Which statement is correct?
- A) Network policies are optional in production if pods are trusted.
- B) Network policies reduce lateral movement by enforcing explicit traffic allow rules.
- C) One broad allow policy is enough for all namespaces.

5. Why is it risky to merge network policy changes together with app rollout changes?

6. You can reach `backend.develop` from a pod in `staging`, but this should be blocked. What should you inspect first?

7. Name one hard stop condition before applying restrictive network policies.

8. What is the preferred rollback approach for a bad policy rollout?
- A) wait and hope controllers self-heal connectivity
- B) delete/revert the exact policy changes and re-verify connectivity
- C) disable all security controls cluster-wide

9. Why should ingress allow rules be scoped to ingress-controller namespace instead of all namespaces?

10. Complete the course guardrail statement:
- A) AI proposes, humans approve, guardrails enforce
- B) AI applies live network changes directly in production
- C) Skip isolation in `develop` because it is non-prod

## Answer Key (Short)

1. It minimizes blast radius by denying unintended traffic first.
2. `Ingress` and `Egress`.
3. DNS egress allow policy to kube-dns/CoreDNS on port 53.
4. B
5. It creates correlated failures and makes root-cause/rollback slower.
6. Existing `NetworkPolicy` selectors, namespace labels, and unintended broad allow rules.
7. Example: wrong namespace target, no rollback path, mixed risky changes in one PR.
8. B
9. It enforces least privilege and keeps east-west exposure narrow.
10. A
