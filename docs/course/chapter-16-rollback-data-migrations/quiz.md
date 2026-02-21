# Quiz: Chapter 16 (Rollback and Data Migrations)

## Questions

1. Why is "application rollback" not always enough after a bad migration?

2. What is the correct high-level order in expand/contract strategy?

3. Which type of migration is safe to run before new application code?

4. Why should destructive migrations be delayed?

5. Which statement is correct?
- A) Drop-column migration can run before compatibility verification.
- B) Feature flags reduce rollback risk during migration rollout.
- C) Migration rollback should always drop newly added columns immediately.

6. Name two mandatory preconditions before contract migration.

7. During rollout errors, what is typically the first mitigation action?

8. If contract migration already broke compatibility, best response is:
- A) keep deploying app versions until one works
- B) trigger incident protocol and data recovery workflow
- C) disable monitoring to reduce noise

9. Why is a rollback window required for migration releases?

10. Complete the guardrail:
- A) no rollback window, no migration rollout
- B) destructive migration first, cleanup later
- C) schema and app breaking changes should always ship together

## Answer Key (Short)

1. Schema state may be incompatible with older application versions.
2. Expand schema -> deploy app/flag rollout -> contract schema.
3. Expand/additive migration.
4. It removes compatibility safety and can block rollback paths.
5. B
6. Example: stable compatibility window and fresh backup/restore evidence.
7. Disable feature flag and/or rollback app while keeping expanded schema.
8. B
9. It preserves time to detect issues and recover safely before destructive changes.
10. A
