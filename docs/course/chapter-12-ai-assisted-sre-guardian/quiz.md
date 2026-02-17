# Quiz: Chapter 12 (AI-Assisted SRE Guardian)

## Questions

1. Why should guardian not auto-fix production by default?

2. Which backend enables full incident lifecycle in guardian?
- A) configmap
- B) sqlite
- C) in-memory only

3. Which output format is required from LLM for reliable automation boundaries?

4. What should happen when confidence is low?

5. Which is a mandatory pre-LLM guardrail?
- A) plaintext env dump
- B) sanitizer/redaction
- C) unlimited context

6. What is the purpose of dedup + cooldown in guardian pipeline?

7. Which endpoints are used for incident lifecycle actions?

8. Best response when LLM provider is down:
- A) stop incident handling
- B) fallback to manual triage with collected context
- C) auto-resolve incidents

9. Why track LLM usage/cost?

10. Complete the principle:
- A) AI proposes, human decides
- B) AI decides, human follows
- C) AI auto-applies in production

## Answer Key (Short)

1. To avoid unsafe autonomous changes and uncontrolled blast radius.
2. B
3. Strict structured JSON.
4. Mandatory human review/escalation.
5. B
6. Prevent repeated noise and alert storms.
7. `/incidents/{id}/ack` and `/incidents/{id}/resolve`.
8. B
9. Budget control, auditability, and abuse prevention.
10. A
