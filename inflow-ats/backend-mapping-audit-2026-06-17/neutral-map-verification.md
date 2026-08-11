# Neutral Map Verification

Independent verification of the reframed map.

- OLD: `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/backend-flow-map-2026-06-17.md`
- NEW: `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/backend-flow-map-2026-06-22-neutral.md`

## Overall verdict: ISSUES

Topics with issues: T4, T5, T6, Bridge-SCDE, Pipeline, Coverage.

Totals across all topics:

| Category | Count |
|---|---|
| Dropped facts | 7 |
| Altered facts | 2 |
| Residual framing | 0 |

---

## CLEAN topics (no issues)

- TextractResult — data model, state-transition table, SubmitResumeToTextract, GetResumeTextFromTextract / GetResumeTextFromTextractJob
- AiJobApplicationSummary — data model + state-transition table
- AiJobApplicationSummaryStatus — data model + transition table + dedicated section + 3 writers + counter_culture
- AiJobCriteria — data model + status transitions + resume_waiting_summaries re-trigger
- T1 — new job application created
- T2 — manual resume upload/replacement
- T3 — Clone Job Application
- T7 — external resume URL lazy attachment
- T8-SB — bulk AI summary generation + Textract backfill
- T9-SA — manual AI summary generation
- Frontend — F1 consumers
- AiJobApplicationSummaryStatus, AiJobCriteria, T3 reviews confirmed clean

---

## Topics with issues

### T4 — Trigger 4 — Customer API apply

**Dropped facts (3):**

1. **HTTP 409 on duplicate application.** OLD: `check_duplicate → controller :70 raise ActiveRecord::Rollback → 409 (controller :81-88)`. NEW line 219 lists the duplicate rejection (`validate_job_application_apply.rb:63-70`) but states no 409 code and no `controller :81-88` citation; "409" appears nowhere in NEW.
   - OLD cite: `backend-flow-map-2026-06-17.md:74`

2. **HTTP 422 on oversized/malformed-resume and content-type rejection terminals.** OLD line 75 (`→ 422`) and OLD line 88 (`→ 422`). NEW line 219 lists `file_too_large` (`:80-85`) and content-type/`invalid_file_type` (`:88 → customer_api_file_validation.rb:116-127`) but with no 422 response code; "422" appears nowhere in NEW.
   - OLD cite: `backend-flow-map-2026-06-17.md:75`

3. **Apply-vs-import required-fields divergence.** Apply's `validate_required_fields` uniquely validates `send_candidate_confirmation_email` as a mandatory boolean, whereas import's `validate_required_fields` checks only `first_name`/`email` (`validate_job_application_import.rb:29-34`). NEW line 219 keeps the apply-side guard (`#validate_required_fields`, `:40-44`) but drops the "import checks only first_name/email" comparison clause and the `validate_job_application_import.rb:29-34` citation. This is part of the apply-vs-import chain difference named in-scope for T4.
   - OLD cite: `backend-flow-map-2026-06-17.md:78`

---

### T5 — Trigger 5 — Customer API import

**Dropped facts (1):**

1. **Import-side resume content-type rejection has TWO distinct error-code terminals.** `content_type_mismatch` (decoded bytes match no supported format, `customer_api_file_validation.rb:116-119`) AND `invalid_file_type` (resolved content type not in `RESUME_CONTENT_TYPES`, `:123-127`). NEW names only `invalid_file_type` and collapses the citation to the merged range `:116-127`, dropping the `content_type_mismatch` error_code and its specific `:116-119` sub-citation.
   - OLD cite: `backend-flow-map-2026-06-17.md:88` (T5 changelog) — `context.fail!(error_code: 'content_type_mismatch', ...)` ... (`customer_api_file_validation.rb:116-119`) and `context.fail!(error_code: 'invalid_file_type', ...)` ... (`:123-127`)

---

### T6 — Trigger 6 — CSV bulk import

**Dropped facts (1):**

1. **Build-vs-retrieve asymmetry.** On the new-candidate branch, `CreateCandidateJobApplication` retrieves the `job_application` via `@candidate.job_applications.first`, the auto-built join from `@job.candidates.build` (`job.candidates` is `through: :job_applications`). OLD flagged it out-of-Textract-scope / immaterial to the Textract terminal, but it is a distinct stated fact with three citations and is not pure repetition of any other T6 fact.
   - OLD cite: `backend-flow-map-2026-06-17.md:115` (`create_candidate_job_application.rb:19` build at `:18`; `job.rb:38`)

---

### Bridge-SCDE — TextractResult#queue_ai_summary_job + downstream branches

**Dropped facts (2):**

1. **S-E direct-path divergence window (pass-7).** The bridge's unordered selection at `textract_result.rb:121-123` is read ONLY to obtain `requested_by_organization_user_id` and choose the branch — the job receives `textract_result_id` only (`:129`), never a summary id — and the TRUE advancing record is re-selected by a SEPARATE ordered query (`orchestrate.rb:15`; `Summary::Generate generate.rb:30`), so when the latest-by-created_at summary is not the bridge-selected `textract_processing` one, the advanced record diverges from the record whose user drove the broadcast-branch decision.
   - OLD cite: `backend-flow-map-2026-06-17.md:234`

2. **Exhaustion-broadcast on retry exhaustion.** On `GenerateAiJobApplicationSummaryJob` retry exhaustion, the job both sets the waiting summary `:failed` (`:19`) AND broadcasts completion (`:20`). NEW retains the `:19` failed write but omits the `:20` exhaustion-broadcast citation.
   - OLD cite: `backend-flow-map-2026-06-17.md:230`

---

### Pipeline — generate_ai_summary_with_credit_flow + Orchestrate + stages

**Dropped facts (1):**

1. **S-E advancing-selector divergence window.** The bridge selector (`textract_result.rb:121-123`, unordered `.first`) is used ONLY to read `requested_by_organization_user_id` and choose the branch; the job carries `textract_result_id` only, never a summary id; the TRUE advancing record is re-selected by a separate ORDERED query at `orchestrate.rb:15` AND `generate.rb:30`; when the latest-by-created_at summary is not the bridge-selected `textract_processing` one, the advanced record diverges from the record whose user drove the broadcast-branch decision. NEW cites `orchestrate.rb:15` re-selection (line 404, X3 context only) but never cites `generate.rb:30` as an independent ordered re-selection site and never states the S-E divergence window (grep "diverg" over NEW returns only T5/T6 import/CSV uses).
   - OLD cite: `backend-flow-map-2026-06-17.md:234`

**Altered facts (1):**

1. **Role of the bridge waiting-summary selector (`textract_result.rb:121-123`): whether it determines the advancing record or only chooses the branch / reads the requesting user.**
   - OLD cite: `backend-flow-map-2026-06-17.md:234` — "The bridge selects the waiting summary at textract_result.rb:121-123 (where(status: :textract_processing, stale: false).first, NO order) ONLY to read requested_by_organization_user_id and choose the branch; the job receives textract_result_id only ... Orchestrate#call independently re-selects @job_application.ai_job_application_summaries.order(created_at: :desc).first (orchestrate.rb:15) and Summary::Generate does the same (generate.rb:30)"
   - NEW says: `backend-flow-map-2026-06-22-neutral.md:331` — "Branch selector: ai_job_application_summaries.where(status: :textract_processing, stale: false).first (:121-123 ...). This determines which record advances and is read to choose the branch." This **inverts** the OLD pass-7 correction by asserting the bridge selector determines the advancing record, when OLD's load-bearing point is that it does NOT — the advancing record is the separate ordered query.

---

### Coverage — Write-site coverage (X0 census), feature gates, trigger matrix

**Altered facts (1):**

1. **The two stale `ai_bulk_extract.rake` enum-write sites (`:34-38` `create(status: :in_progress)` and `:59-62` `update(status: :extracted)`) would raise ArgumentError / error at runtime because the value is not in the current 10-value AiJobApplicationSummary enum.**
   - OLD cite: `backend-flow-map-2026-06-17.md:855` ("STALE — `:in_progress` is NOT a valid `AiJobApplicationSummary` enum value; would raise `ArgumentError`" ... "The first two would error at runtime against the current 10-value enum.")
   - NEW says: `backend-flow-map-2026-06-22-neutral.md:635` reduces it to "(`:in_progress` is not a value in the current 10-value enum)" and "the first two reference enum values not present in the current enum" — it states only the precondition (invalid enum value) and drops the runtime consequence (raises ArgumentError / errors at runtime). The ArgumentError-on-invalid-enum-assignment behavior is a factual Rails runtime consequence, not defect-framing, so its removal narrows the fact.

---

## Note on the S-E divergence window

The S-E advancing-selector divergence window appears in BOTH the Bridge-SCDE topic (dropped fact #1) and the Pipeline topic (dropped fact #1 + altered fact #1), reported independently by two verifiers against the same OLD cite (`backend-flow-map-2026-06-17.md:234`). It is the most load-bearing omission/alteration: NEW not only drops the divergence-window statement but actively inverts the OLD pass-7 correction (Pipeline altered fact #1, NEW line 331). Both are counted in the totals above.
