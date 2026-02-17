# Quiz: Chapter 06 (Security Context & Pod Hardening)

## Questions

1. Why is `runAsNonRoot: true` a production guardrail?

2. What risk does `allowPrivilegeEscalation: false` reduce?

3. Why use `capabilities.drop: [ALL]` by default?

4. What does `readOnlyRootFilesystem: true` force teams to do?

5. Which statement is correct?
- A) If a pod fails on permissions, run it as root.
- B) Use explicit writable volume mounts and keep non-root execution.
- C) Disable seccomp for easier debugging.

6. Name one signal that a pod is not properly hardened.

7. Why is `seccompProfile: RuntimeDefault` important?

8. Best rollback for a broken hardening change is:
- A) patch live pod with root and continue
- B) revert manifest in Git and let Flux reconcile
- C) disable all admission/security controls

9. Which control pair best limits container escape surface?

10. Complete the course rule:
- A) AI can bypass pod hardening in urgent incidents
- B) guardrails stay on; fixes must preserve security baseline
- C) non-prod should ignore hardening

## Answer Key (Short)

1. Prevents root execution and reduces privilege abuse surface.
2. Blocks gaining additional privileges via setuid/setcap paths.
3. Minimizes Linux kernel attack surface and unnecessary privileges.
4. Declare required writable paths explicitly (for example `/tmp`, cache/run dirs).
5. B
6. Example: `runAsUser: 0`, privileged mode, no seccomp, writable root FS without justification.
7. It applies a safer syscall profile and reduces kernel exploit surface.
8. B
9. Non-root execution + dropped capabilities (plus no privilege escalation).
10. B
