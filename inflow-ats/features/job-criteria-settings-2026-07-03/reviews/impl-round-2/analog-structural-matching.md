# Analog Structural Matching (always-on check, pipeline rule 14) — Round 2

Structural comparison vs `GenerateAiJobApplicationSummaryJob` and controller/serializer analogs, re-confirmed at merged HEAD. All deviations remain the pre-adjudicated set (flags 1-7); no NEW deviations introduced by the fix commit or the merge:

- **Parameter interfaces:** `perform(ai_job_criteria_id, requesting_organization_user_id = nil)` — flag 4 (adjudicated positional). Exhaustion block reads `job.arguments.first`/`.second` — the positional counterpart of the analog's `job.arguments.first[:key]` reads. Controller: zero params methods (no body params) — justified.
- **Retry/exhaustion:** broadcast added in the `retry_on` exhaustion block after the failure write, with the analog's row-exists guard shape. Dual-rescue shape (`CustomErrorAiSummary` re-raise; StandardError terminal write + broadcast) mirrors the analog.
- **Callbacks:** no new callbacks on `AiJobCriteria`/`Job` (diff-verified; `resume_waiting_summaries` untouched).
- **Broadcast helper:** guard ladder order matches the analog (find org user → user → reload → terminal check → payload → broadcast); conditional `errorMessage` shape matches.
- **Serializer/status-pointer deviation** (dedicated endpoint vs parent-serializer ride-along): spec-adjudicated; premise re-checked in the implemented UI — criteria status is consumed ONLY by `JobCriteriaSection` in the settings tab; nothing else fetches it.
- **Bulk controller parameter interface after the merge:** now `job:` + `params:` + (`kind:`) — matches develop's OWN post-#3054 shape for this exact controller; the feature's `job:` input follows the interactor-context convention the analog interactors use. No raw-ID-array or client-side resolution introduced.
- **Section button analog parity (round-1 F1):** `loading` + `disabled` both present now — matches `PlatoTab.tsx:239`.

Surfaced-not-adjudicated cosmetic deviations from round 1 (confirm-modal primary `type="button"`, no `size="medium"`, no `className="submit-button"`) remain recorded as LOW in code-quality.md.

## Findings

No issues found at MED+ severity.
