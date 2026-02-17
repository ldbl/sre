# Quiz: Chapter 09 (Observability)

## Questions

1. Why is “metrics -> traces -> logs” the preferred incident flow?

2. In this MVP, where is telemetry exported from?
- A) only in-cluster OTel collector
- B) directly from frontend/backend to Uptrace
- C) only backend exports telemetry

3. What header set is required for end-to-end context propagation?

4. Which backend endpoint is used for controlled crash correlation drill?

5. Which signal should confirm symptom first during incident triage?

6. If backend spans are orphaned (not linked to frontend), what should you inspect first?

7. What evidence pair is minimum to claim correlation works?

8. Which statement is correct?
- A) Logs-only debugging is enough for production incidents.
- B) Trace ID correlation between spans and logs reduces MTTR.
- C) Sampling should always be 100% in every environment.

9. Why must telemetry secrets never be committed in plaintext?

10. Complete the guardrail:
- A) choose action only after evidence from at least two signals
- B) rollback immediately without checking traces
- C) ignore metrics if logs look fine

11. What is the backend availability SLO target in this baseline?

12. Why are burn-rate alerts used in addition to plain error-rate alerts?

## Answer Key (Short)

1. It narrows from symptom to path to concrete evidence, reducing guesswork.
2. B
3. `traceparent`, `tracestate`, `baggage`.
4. `GET /panic`.
5. Metrics deviation (latency/error-rate/request-rate anomaly).
6. CORS + propagation config on frontend/backend and instrumentation status.
7. One trace chain plus one backend log entry with matching `trace_id`.
8. B
9. They expose credentials/tokens and break security/compliance baseline.
10. A
11. 99.5% (30-day window).
12. They detect fast and sustained error-budget consumption early, not only instantaneous spikes.
