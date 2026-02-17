# Quiz: Chapter 11 (Controlled Chaos)

## Questions

1. Why should chaos drills start in `develop` and not production?

2. Which CronJob field is the primary kill switch for Chaos Monkey?

3. In this repo, what target app labels are allowed for monkey pod deletion?

4. Which incident flow is required before mitigation decisions?

5. Which statement is correct?
- A) Chaos drills are successful without evidence if service recovers.
- B) Controlled chaos requires blast-radius limits and rollback path.
- C) Chaos Monkey should run in all namespaces for realistic behavior.

6. What is the minimum evidence set per drill?

7. Why run deterministic failure drills before monkey mode?

8. If monkey remains enabled outside exercise window, what is the correct action?
- A) ignore
- B) disable immediately and record incident
- C) increase frequency

9. What should be produced after each game day?

10. Complete the guardrail:
- A) one failure injection at a time
- B) inject all failure modes simultaneously
- C) skip verification if pods restart

## Answer Key (Short)

1. To contain blast radius and validate process safely.
2. `spec.suspend`.
3. `app=frontend` and `app=backend`.
4. metrics -> traces -> logs.
5. B
6. Symptom metric, representative trace, correlated log evidence.
7. They are repeatable and help calibrate detection/response first.
8. B
9. Scorecard and hardening action items.
10. A
