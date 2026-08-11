# Analog Structural Matching (always-on check, pipeline rule 14) — Round 3

Signature-level diff against `GenerateAiJobApplicationSummaryJob` and the analog frontend/controller layers, re-done from the files at HEAD:

- **Parameter interface**: `perform(ai_job_criteria_id, requesting_organization_user_id = nil)` — positional vs the analog's kwargs is FLAG 4, pre-adjudicated (spec review round 1: kwargs cutover breaks in-flight positional payloads at deploy). Implemented exactly as adjudicated, with argument reads (`job.arguments.first`/`.second`) in the signature's own shape — the structural counterpart of the analog's `job.arguments.first[:key]` reads.
- **Retry/exhaustion**: broadcast ADDED to the existing `retry_on` exhaustion block after the failure write (not only in perform/rescue), guarded `if ai_job_criteria` exactly like the analog's `if textract_result` guard.
- **Error-handling shape**: dual-rescue mirror — `rescue CustomErrorAiSummary => e ... raise` (re-raise for retry, no broadcast mid-retry) + `rescue StandardError` terminal write then broadcast gated on row AND requester, matching the analog's `if textract_result && requesting_organization_user_id`.
- **Broadcast helper ladder**: lookup requester → user → reload → terminal-status guard → payload (camelCase keys, conditional errorMessage) → `GlobalChannel.broadcast_to` — same order as analog :50-80.
- **Callbacks**: no new callbacks on `AiJobCriteria`/`Job` (diff adds constants/predicates/method changes only; `resume_waiting_summaries` untouched).
- **Controller**: no gratuitous params method (no body params to permit); exists/authorize/render shapes match `ai_job_application_summaries_controller.rb`; create-returns-resource matches.
- **Serializer status-pointer deviation** (dedicated endpoint instead of parent-serializer ride-along): spec-adjudicated (SPEC 5.1); premise re-verified in the implemented UI — criteria status is consumed ONLY by `JobCriteriaSection` in the settings tab (hook consumer grep), and `Api::V1::JobSerializer` gained nothing.
- **Frontend**: confirm modal structurally matches `BulkGenerateAiSummariesConfirmModal` (internal mutation, both behavioral props, `dismissModalWithAnimation(() => onCancel)`, error toast + stays open); hook matches `useAiJobApplicationSummary` form. Remaining button attribute deltas are the recorded LOW carryover.

No unadjudicated structural deviation found (flags 1-7 are the only divergences, all implemented per their rulings).

## Findings

No issues found.
