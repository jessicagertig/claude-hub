# Analog Structural Matching (always-on check, own file; pipeline rule 14) — Round 1

Compared SIGNATURES and shapes against `GenerateAiJobApplicationSummaryJob` and the layer analogs. Every deviation surfaced; only flags 1-7 are pre-adjudicated.

## Parameter interfaces

- `ExtractJobCriteriaJob#perform(ai_job_criteria_id, requesting_organization_user_id = nil)` vs analog kwargs — **flag 4, adjudicated; verified honored**: exhaustion block reads `job.arguments.first`/`.second` (positional counterpart of `job.arguments.first[:key]`); all enqueue sites positional and consistent. Not re-litigated.
- Controller accepts no body params vs analog's nested-resource params — justified (endpoint takes no inputs); no gratuitous params method appeared.
- `extract_job_criteria_immediately(requesting_organization_user_id: nil)` kwarg threading — flag 1, mirrors the analog's requesting-user threading. ✓

## Retry/exhaustion patterns

- Analog broadcasts from its `retry_on` exhaustion block behind an `if <record>` guard; new job does EXACTLY that (`if ai_job_criteria` wrapping write + broadcast). The broadcast was added at the exhaustion site, not only perform/rescue. ✓
- Exhaustion failure write stays `update_columns` (pre-existing site style; sibling writes in this job and ExtractCriteria all use `update_columns`) vs the analog's `update` on summaries — pre-existing difference between the two record types' write conventions, NOT introduced by this diff. Surfaced for completeness; no change recommended.

## Callback patterns

- No new callbacks on `AiJobCriteria` or `Job` (diff verified — constants/predicates/method changes only; `resume_waiting_summaries` untouched). ✓ No unspecced enum values, no validation changes (rule 20 boundary clean).

## Error-handling shapes

- Dual rescue mirrors the analog exactly: `rescue CustomErrorAiSummary => e; ap; raise` then `rescue StandardError => e` with `Rails.logger.error` + `ap` + failure write + gated broadcast (`if ai_job_criteria && requesting_organization_user_id` ≙ analog's `if textract_result && requesting_organization_user_id`). ✓
- Broadcast helper guard ladder in analog order: OrganizationUser → user → fresh record state → terminal check → payload → conditional errorMessage → `GlobalChannel.broadcast_to`. One shape difference: fresh state via `ai_job_criteria.reload` vs the analog's re-query — SPEC-verbatim, R-1 gate-bound (noted in code-quality.md, not counted this round).

## Serializer/status-pointer deviation

- Status rides the dedicated endpoint instead of the parent serializer — spec-adjudicated (SPEC 5.1) with rationale "criteria status needed ONLY in this settings tab"; verified the premise holds in the implemented UI (the only consumer is `JobCriteriaSection` in the settings tab; the WS handler invalidates rather than reads) and `Api::V1::JobSerializer` was NOT touched. ✓

## Frontend structural comparisons

- Hook: query key array form, `enabled: x != undefined`, hook-level onSuccess invalidation — byte-level match to `useAiJobApplicationSummary`'s shapes. ✓
- Confirm modal: mutation ownership, both behavioral props, `dismissModalWithAnimation(() => onCancel)`, error toast + stays open — matches `BulkGenerateAiSummariesConfirmModal` structurally. Surfaced attribute-level deviations (primary `type`, `size`, `className`) — code-quality F5 [LOW].
- **Section generate button deviates from the generate-button analog** (`PlatoTab.tsx:239` passes `loading` AND `disabled`): missing `disabled={isInFlight}` — this is F1 [HIGH], owned by frontend-display-states.md.
- WS handler case, payload interface, sidebar register, LoadingIndicator treatment, CenterModal/FullModal usage — all structurally matched to their cited analogs (verified against source).

## Findings

- (Cross-reference) F1 [HIGH] — section button missing `disabled={isInFlight}` vs the PlatoTab generate-button analog; counted once in frontend-display-states.md.
- All other deviations are LOW and recorded in code-quality.md (F5) or noted-not-counted (reload, R-1).
