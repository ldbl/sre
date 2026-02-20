# Quiz: Advanced Module (Linkerd + Progressive Delivery)

## Questions

1. Why is progressive rollout safer than immediate 100% rollout?

2. What is the main value of Linkerd in canary operations?

3. Which signal is mandatory for automated canary abort decisions?

4. Why should A/B routing be time-bounded?

5. Which statement is correct?
- A) Canary without abort criteria is acceptable in production.
- B) Mesh telemetry can provide per-route success/latency for rollout decisions.
- C) A/B rules should stay permanently after experiment end.

6. Give one valid canary traffic progression pattern.

7. What is the safest first action when canary error rate spikes?

8. A/B test shows no measurable improvement. Best response:
- A) keep split active indefinitely
- B) revert experiment and record result
- C) increase blast radius immediately

9. Why is `develop/staging` rehearsal required before production canary?

10. Complete the guardrail:
- A) no SLO gates, no progressive delivery
- B) canary gates are optional when release is urgent
- C) route split alone guarantees safety

## Answer Key (Short)

1. It limits blast radius and enables earlier failure detection.
2. Service-level telemetry and identity/mTLS guarantees.
3. Explicit SLO thresholds (for example error rate and latency).
4. To prevent long-lived routing drift and unclear ownership.
5. B
6. Example: 5% -> 25% -> 50% -> 100%.
7. Abort/rollback and investigate with metrics and events.
8. B
9. It validates policy, telemetry, and rollback path safely.
10. A
