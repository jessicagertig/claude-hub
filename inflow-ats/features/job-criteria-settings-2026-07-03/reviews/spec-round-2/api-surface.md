# Round 2 — Angle 4: API surface

SPEC.md re-read in full. Round 1's table-cell amendment (§5.3 "First extraction running" → `false`) verified in place; cross-checked ALL six table rows against the serializer methods once more — internally consistent, and consistent with §12's controller-spec state list and §8.2's derivation rules. Route/controller/serializer/authorization sections otherwise unchanged; Round 1 verifications stand.

New check this round (fresh eyes on §5.2 convention notes):

- F1 evidence: §5.2 cited "`useBulkGenerateAiSummaries.ts` path building" as the numeric-job.id job-nested-path example — but that hook's paths are `/bulk_ai_job_application_summaries` and `/bulk_ai_job_application_summaries/all_stages` (useBulkGenerateAiSummaries.ts:22, :47): the job id rides the BODY, not the path. The correct job-nested-path analog is `useBulkMessage.ts:23` — `` path: `/jobs/${jobId}/bulk_channel_messages` `` (verified). The substantive claim (frontend passes numeric `job.id`; no hash_id fallback needed) was and remains correct; only the supporting example was wrong.

## Findings

- F1 [LOW] §5.2 cited a non-job-nested hook (`useBulkGenerateAiSummaries.ts`) as the job-nested path-building example. Fix: cite `useBulkMessage.ts:23`.

## Amendments Applied

1. §5.2 note corrected to cite `useBulkMessage.ts:23` with the actual path form (F1). Patched sentence re-read and verified.
