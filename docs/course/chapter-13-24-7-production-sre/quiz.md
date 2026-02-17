# Quiz: Chapter 13 (24/7 Production SRE)

## Questions

1. What is the first priority in the first minutes of an incident?

2. Which statement is correct?
- A) Decide mitigation first, collect evidence later.
- B) Collect evidence first, then choose mitigation.
- C) Wait for AI confidence to reach 100%.

3. Name the minimum evidence set before high-risk action.

4. Why are blameless postmortems important?

5. Who owns final production decisions when AI is used?

6. What makes an action item “good” in postmortem output?

7. If issue recurs weekly, where should it be tracked besides incident timeline?

8. Correct handling of uncertain diagnosis:
- A) immediate risky change
- B) reduce blast radius and gather more evidence
- C) close incident as transient

9. What should be true before incident closure?

10. Complete the principle:
- A) AI may auto-fix production if confidence is high
- B) AI assists; humans remain accountable for actions
- C) AI replaces on-call

## Answer Key (Short)

1. Acknowledge, assign IC, and classify severity.
2. B
3. Metrics + traces + correlated logs.
4. They improve systems and learning without blame culture.
5. Human on-call/incident leadership.
6. Clear owner, due date, and verification method.
7. Recurring problem/hardening backlog.
8. B
9. Recovery verified and follow-up ownership assigned.
10. B
