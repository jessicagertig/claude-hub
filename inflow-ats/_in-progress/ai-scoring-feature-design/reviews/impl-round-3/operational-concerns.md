# operational-concerns -- Round 3

## Assessment

1. **Error handling propagation:** `CustomErrorAiSummary` propagates from services through orchestrator to job, which has `retry_on`. `JSON::ParserError` and `StandardError` are caught and set `failed` status without re-raise. Error messages stored in `error_message` column. Correct.

2. **Job retry exhaustion:** Both `GenerateAiJobApplicationSummaryJob` and `ExtractJobCriteriaJob` have exhaustion blocks that set `failed` status. This prevents zombie records stuck in `retrying` or `in_progress`. Correct per Known Failure Pattern #14.

3. **Logging:** `ap` debug logs throughout services and jobs. `Rails.logger.error` for actual errors. Matches existing pattern.

4. **Cost tracking:** `AiApiRequest` created after each AI call with tokens, cost, provider, model. All 7+ calls (4 summary + 2 scoring + 1 display + 1 integration) tracked.

5. **Timeout configuration:** OpenAI provider updated with `timeout: 120` and `open_timeout: 30` on the Faraday connection. This prevents indefinite hangs on AI calls.

6. **Temperature setting:** OpenAI provider sets `temperature: 0` for deterministic responses. Appropriate for scoring/extraction use case.

## Findings

No findings.
