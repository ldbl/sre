# Chapter 02 Quiz: Infrastructure as Code (IaC)

## Questions

1. Why is `plan -> review -> apply` safer than direct `apply`?

2. What risk does Terraform state locking prevent?

3. In this repo, what is the purpose of `scripts/guard-terraform-plan.sh`?

4. You have a valid planfile but it is 4 hours old. What should you do and why?

5. What is drift, and why should you address drift before unrelated infrastructure changes?

6. Name two signals in a plan output that should trigger a stop-and-review decision.

7. Why is least-privilege IAM/RBAC relevant to Terraform automation?

8. What must be verified before running a destroy workflow in any environment?

## Answer Key (Short Form)

1. It creates a review checkpoint and prevents unintended changes from being applied blindly.
2. Concurrent state mutation and corruption from overlapping apply operations.
3. It enforces guardrails so apply happens only from reviewed, fresh plan artifacts.
4. Regenerate and re-review the plan because infrastructure and dependencies may have changed.
5. Drift is mismatch between declared and real infrastructure; ignoring it compounds risk.
6. Unexpected deletes, changes in unrelated modules/resources, environment mismatch indicators.
7. It limits blast radius and prevents broad credentials from making uncontrolled changes.
8. Exact environment scope, expected impact, and rollback/recreate path.
