# Quiz: Chapter 07 (Resource Management & QoS)

## Questions

1. Why are requests/limits mandatory for production workloads?

2. What QoS class do pods usually get when requests and limits are both set but not equal?

3. What Kubernetes object enforces namespace-wide total resource caps?

4. What Kubernetes object provides default/min/max resource values per container?

5. Which statement is correct?
- A) BestEffort pods are safest for critical APIs.
- B) ResourceQuota helps prevent one namespace from exhausting cluster capacity.
- C) OOMKilled means the container exceeded CPU limit.

6. Why include ephemeral-storage requests/limits?

7. Preferred response to repeated OOMKilled is:
- A) remove limits
- B) inspect memory profile, adjust requests/limits, verify with metrics
- C) disable probes

8. What is the risk of increasing quotas without capacity review?

9. Which QoS class is obtained when CPU+memory requests equal limits for every container?

10. Complete the guardrail:
- A) scale first, investigate later
- B) evidence first (metrics/events), then resource tuning
- C) disable quotas in non-prod by default

## Answer Key (Short)

1. Predictability, fair scheduling, and controlled blast radius under pressure.
2. Burstable.
3. `ResourceQuota`.
4. `LimitRange`.
5. B
6. To control disk pressure and avoid node instability from runaway writable layers/tmp.
7. B
8. Capacity oversubscription and cross-namespace instability.
9. Guaranteed.
10. B
