# Quiz: Chapter 15 (Admission Policy Guardrails)

## Questions

1. Why is admission policy called the "last safety gate"?

2. What is the safest rollout order for new blocking policies?

3. What does `validationFailureAction: Audit` do?

4. What does `validationFailureAction: Enforce` do?

5. Which statement is correct?
- A) If pre-commit passes, admission control is unnecessary.
- B) Admission control can still block risky manifests after merge.
- C) Fastest fix is always disabling policy engine.

6. Name two risky patterns from Chapter 15 starter pack.

7. What minimum metadata must every break-glass exception include?

8. During incident, a deny blocks rollout. Best first move:
- A) disable Kyverno deployment
- B) read deny reason and fix manifest or apply scoped time-bound exception
- C) grant permanent namespace bypass

9. Why are permanent exceptions an anti-pattern?

10. Complete the guardrail:
- A) no evidence, no policy bypass
- B) exceptions do not need expiry
- C) policy mode can change directly in production without audit phase

## Answer Key (Short)

1. It is the final runtime control before workload admission.
2. Audit in non-production, then selective Enforce, then gradual promotion.
3. It records violations but does not block admission.
4. It blocks violating resources at admission.
5. B
6. Example: `:latest` tags, missing securityContext, missing requests/limits.
7. Owner, reason, scope, expiry, and incident/approval reference.
8. B
9. They create unmanaged risk and normalize unsafe drift.
10. A
