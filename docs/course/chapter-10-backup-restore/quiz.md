# Quiz: Chapter 10 (Backup & Restore Basics)

## Questions

1. Why is a successful backup alone not enough?

2. Which CNPG resource defines periodic backup schedule?

3. Which secret name is used for object-store backup credentials in this repo?

4. What is the safest environment for routine restore simulations?

5. Which statement is correct?
- A) Restore tests can wait until a production incident.
- B) Backup reliability is proven only after successful restore validation.
- C) One-time backup test is enough forever.

6. What are the minimum credential fields needed for object storage in this setup?

7. During restore simulation, what indicates initial success?

8. Preferred response if backup completes but restore fails:
- A) ignore because backups exist
- B) treat as backup incident and fix restore path
- C) disable scheduled backups

9. Why should production restore be controlled by incident protocol?

10. Complete the guardrail:
- A) no restore test, no backup confidence
- B) backup confidence does not require drills
- C) production is the best place to test recovery first

## Answer Key (Short)

1. Because recoverability is not proven until restore works.
2. `ScheduledBackup`.
3. `cnpg-backup-s3`.
4. Develop or staging.
5. B
6. Access key, secret key, bucket (plus optional endpoint/region).
7. Restore cluster reaches ready state and accepts connectivity checks.
8. B
9. It is high risk and can increase customer impact if uncontrolled.
10. A
