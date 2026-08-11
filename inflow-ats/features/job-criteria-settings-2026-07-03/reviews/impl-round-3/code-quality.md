# Code Quality (always-on) — Round 3

Files byte-identical to the round-2 state (verified: clean tree at the same HEAD). Fresh read-through of all new/modified files this round; rounds 1-2 positives independently re-confirmed on the frontend files (line-by-line) and backend diff files.

- Naming: model-derived record variables throughout app code; frontend follows the file-local conventions (Styled namespace, label properties, double quotes).
- Structure: controller/serializer/job/interactor changes all sit in the layer the architecture rules assign them; frontend section extracted per the size rule.
- Readability: guard ladders match analog order; comments limited to the specced/merge-authored explanatory ones (both accurate).

## Findings

- F1 [LOW — new, spec-local nit] spec/interactors/queue_bulk_ai_summary_jobs_spec.rb:203,216 / `ready = job_application_with_textract` names a JobApplication record `ready` / record variables should carry the model name (`ready_job_application` or similar) per the global record-naming rule; spec-local, behavior-irrelevant / rename when next touching the file. Does not affect the verdict (LOW).

LOW carryovers from rounds 1-2, still open, NOT re-opened or counted (listed for tracking): TIERS constant duplicated across `JobCriteriaViewModal.tsx` and `components/JobCriteriaSection.tsx`; `JobCriteriaSection.tsx:43` `<a onClick>` without href; `aiSummaryWebsocketPayloads.ts` missing trailing newline; `RegenerateJobCriteriaConfirmModal.tsx` primary-button attribute deviations vs analog; plus the noted-not-counted `ai_job_criteria.reload` (conventions-pass-owned).

No MED+ findings.
