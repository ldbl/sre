# Quiz: Chapter 08 (Availability Engineering)

## Questions

1. Why is HPA alone not sufficient to guarantee safe disruption handling?

2. What does a PodDisruptionBudget control?

3. Which signal must be checked before node drain?

4. If `Allowed disruptions = 0` for a critical service, what is the correct action?

5. Which statement is correct?
- A) PDB affects all pod failures including OOM and crashes.
- B) PDB controls voluntary disruptions such as evictions/drains.
- C) HPA ignores resource metrics.

6. What does `ScalingLimited=True` typically indicate in HPA status?

7. Why keep `minReplicas` > 1 in staging/production for critical services?

8. Preferred rollback path for bad availability config:
- A) patch random live objects
- B) revert Git manifests and let Flux reconcile
- C) disable autoscaling and PDB permanently

9. Can HPA scale if metrics are unavailable?

10. Complete the guardrail:
- A) drain first, verify later
- B) verify HPA + PDB state first, then perform disruption
- C) remove PDB to speed up maintenance

## Answer Key (Short)

1. HPA scales capacity; it does not enforce safe eviction/disruption rules.
2. Voluntary disruption budget for selected pods.
3. PDB `Allowed disruptions` (plus HPA/replica readiness).
4. Stop and adjust capacity/budget first.
5. B
6. Desired scale is capped by min/max bounds or target constraints.
7. Preserves service continuity during rollout/drain events.
8. B
9. Not reliably; autoscaling decisions depend on available metrics.
10. B
