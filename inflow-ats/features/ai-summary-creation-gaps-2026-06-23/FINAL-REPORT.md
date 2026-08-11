# Final Report — AI Summary Creation Gaps + docx→Textract (2026-06-23)

Errors, gaps, and bugs found, and the code fixes applied. **Non-spec (code) focus.** Repo: `/Users/jessica/wrk/wrk-corp/inflow-ats`, branch `ai-summary-creation-gaps`. All work left uncommitted on the branch; `db/schema.rb` never staged.

## TL;DR

Six creation/visibility gaps in the AI-summary/criteria pipeline were proven against live code, then fixed as surgical edits. The reported "criteria stuck `pending`" incident's true root cause was found to be a **Rails-6.1 enqueue-inside-transaction race**, not the `has_one`→`has_many` change. Change set: 13 app/FE files modified + 1 new app interactor (`ValidateAutoAiSummaryGeneration`) + 2 new specs; `db/schema.rb` never staged.

---

## Bugs / gaps found, and the fix applied (non-spec)

### 1. Auto-generate never created an `AiJobApplicationSummary` (the incident: failed Textract → no summary at all)
- **Found:** the auto-gen decision lives only in the bridge (`textract_result.rb:137-143`), which fires only after Textract succeeds; with no pre-existing summary it enqueues a job that bails in `Orchestrate#call` (`orchestrate.rb:16`) — so **no summary is ever created on the auto path**, on Textract failure *or* success. Confirmed by an in-code comment in `bulk_generate_ai_summaries_job.rb:70-72` ("…or Orchestrate finds no row and bails"). Reproduced: a new auto-gen application had 0 summaries.
- **Fix (W1):** a new **validation** interactor `ValidateAutoAiSummaryGeneration` runs the four AI preconditions without re-submitting Textract (intake already submits) and produces the `textract_pending`/`textract_result` context that the existing `CreateAiSummaryGeneration` consumes. `enqueue_new_job_application` calls validate-auto → (on success) `CreateAiSummaryGeneration`, which builds the `textract_processing` summary. Creation logic stays in exactly two places — `CreateAiSummaryGeneration` (single, now reused by auto) and `CreateBulkAiSummaryGeneration` (bulk); the auto/manual difference lives only in validation. The existing bridge then advances the summary.

### 2. `.docx` resumes raced Textract and produced no usable `TextractResult`
- **Found:** intake enqueued `DocxToPdfJob` and `SubmitResumeToTextractJob` with no ordering. `DocxToPdfJob` does a slow (~180s) ConvertApi call; the fast Textract submit usually wins and sends the **raw `.docx`** to AWS Textract (PDF-only) → `textract_job_result_text` never set → the bridge guard (`textract_result.rb:115`) blocks summary generation. No automatic actor recovers it. Holds under both AWS failure modes.
- **Fix (W2):** branch on `resume_is_docx` at both creation sites (`enqueue_new_job_application`, T2 controller): PDFs submit Textract directly; docx defers. `DocxToPdfJob#perform` now enqueues `SubmitResumeToTextractJob` after the conversion attempt (gated on `resume_is_docx` + `TEXTRACT_RESUME_PROCESSING`), so Textract receives the PDF; conversion failure still attempts (no regression).

### 3. Status row stuck at `initial_summary_pending` after a failed initial generation ("generating forever")
- **Found:** when an initial summary generation fails, `update_summary_status_record` (which fires only on `→succeeded`, and whose dominant failure writers use `update_columns` and bypass the callback) never moves the row off `initial_summary_pending` — so the row looks perpetually "generating."
- **Fix (W5 + C1):** the `AiJobApplicationSummaryStatus` enum is **left unchanged** (no `failed` value — it only tracks progress toward a *succeeded* review). `AiJobApplicationSummary#record_failure(error_message)` sets the summary to `:failed` (where failure actually lives) and then, **only if the status row is `initial_summary_pending`, returns it to `none`** (clearing the pointer); a row at `current`/`regenerating` (a prior succeeded review) is **left untouched** so that review stays accessible. Routed the 8 terminal-failure sites + the Textract-exhaustion path (C8) through it. Added `return if stale?` to `update_summary_status_record` so a stale summary reaching `succeeded` never copies stale data onto the row (C1). The detail card's failure display comes from the **summary's** `failed` status via the existing `PlatoTab` branch — not from the status row.
  - **Course-correction:** an earlier version of this added a `failed:4` value to the status enum and transitioned `current → failed` (wiping a prior review). Jessica flagged this as wrong infrastructure; it was fully reverted to the behavior above. No status-enum change ships.

### 4. No UI signal while a summary is `awaiting_job_criteria` / `retrying` (frozen detail card)
- **Found:** both states were excluded from `BROADCAST_STATUSES`, so transitions into them broadcast nothing; the detail card's full-summary query was never invalidated and froze on the last step. The generate-path `retrying` writer used `update_columns` (no callback at all).
- **Fix (W4):** added `awaiting_job_criteria` + `retrying` to `BROADCAST_STATUSES`; converted `summary/generate.rb:175` retrying `update_columns`→`.update` (preserving `error_message`); extended the FE `PlatoGenerationStatus` union + `STATUS_TO_STEP` so the stepper renders them.

### 5. "Criteria stuck `pending` forever" — true root cause was an enqueue-inside-transaction race (NOT `has_one`→`has_many`)
- **Found:** the `has_many :ai_job_criteria` refactor is internally consistent and prevents the *overwrite* failure mode — but it does **not** fix the incident. The real cause: `auto_extract_job_criteria` ran inside the Job `before_update` transaction (`handle_status_changed_to_published` / `handle_description_change`), doing `AiJobCriteria.save` + `ExtractJobCriteriaJob.perform_later` **pre-commit**. On Rails 6.1.7.7 (no `enqueue_after_transaction_commit`) a Sidekiq worker can run the job before the row commits → `find_by` nil → silent exit → criteria stuck `pending`; the `pending` poison-guard then blocks all future extraction (incl. a manual generate). Reproduced: a stuck-`pending` latest criteria makes `extract_job_criteria`/`auto_extract_job_criteria` no-ops and parks dependent summaries at `awaiting_job_criteria`.
- **Fix (W3):** moved the criteria-extraction trigger off `before_update` into a dedicated `after_commit :handle_criteria_extraction_after_commit` (NOT inside `handle_after_update_commit`, so it bypasses the `skip_update_callback` early-return). Detects publish (`saved_change_to_status? && published?`) and meaningful description change via the saved-change API (avoiding the `description_was` post-commit dirty-tracking trap — added `description_saved_change_is_meaningful?` + extracted `sanitize_for_compare`). The criteria row now commits before its job is enqueued.

### 6. Criteria-resumed summary lost its completion toast
- **Found:** `resume_waiting_summaries` re-enqueued `GenerateAiJobApplicationSummaryJob` with only `textract_result_id`, dropping the requesting user → a manually-requested summary resumed after criteria succeeded got no `AI_SUMMARY_COMPLETE` toast.
- **Fix (W6):** pass `requesting_organization_user_id: ai_job_application_summary.requested_by_organization_user_id` through the re-enqueue (nil for auto, restored for manual).

### 7. Status row read `none` for in-progress / regenerating applications (your TDD tests)
- **Found:** `FindOrCreateAiJobApplicationSummaryStatus` create-path collapsed every non-succeeded case to `none`, so an application actively generating (or regenerating over a prior succeeded review) showed "no summary" instead of an in-progress state. (Documented by your two failing tests.)
- **Fix:** create-path now sets `initial_summary_pending` (in-progress, no prior succeeded), `regenerating` (in-progress + a prior succeeded, adopting its denormalized data), or `none` — guarded by a `generation_in_progress` predicate (`!succeeded? && !failed? && !stale?`) so a stale-succeeded record is NOT shown as in-progress. Reordered `enqueue_new_job_application` to create the auto summary **before** the status row, so an auto-gen application's row reads `initial_summary_pending` at intake.

---

## Errors caught and corrected DURING implementation
- **W1 wrong layer (caught by Jessica, refactored):** the first cut added a new *create* interactor (`CreateAutoAiSummaryGeneration`) that duplicated both the precondition gates and the build. The auto/manual difference is only the Textract submit, which lives in *validation* — so the right shape is a new `ValidateAutoAiSummaryGeneration` that reuses `CreateAiSummaryGeneration`. Refactored: deleted the create-auto interactor, added validate-auto, reused the single-send creator. Creation logic now lives in exactly two places (single + bulk).
- **W5 over-reach (caught by Jessica, reverted):** I wrongly added a `failed` value to the `AiJobApplicationSummaryStatus` enum and made `record_failure` transition `current → failed`, wiping a prior succeeded review on a regeneration failure. The status enum exists only to check for a *succeeded* review; it must not track failures. Fully reverted to: failure → `initial_summary_pending`→`none`, `current`/`regenerating`→untouched (see issue 3). The failed-enum value, the `current→failed` transition, and the FE `"failed"` union additions were all removed.
- **`generation_in_progress` predicate gap:** my first FindOrCreate edit caught a stale-succeeded summary in the in-progress branch (would have shown `initial_summary_pending` for a superseded review). Caught by the existing stale-succeeded test (`:132`); fixed by requiring `!succeeded? && !failed? && !stale?`.
- **PDF double-submit (caught at spec-review):** the first W2 draft enqueued Textract from `DocxToPdfJob` unconditionally → PDFs would submit twice; gated on `resume_is_docx`.

---

## Phase 6 adversarial review

Round 1 (7 angles completed before a transient API error; files in `reviews/impl-round-1/`) found **zero correctness issues** across analog-structural-matching, W2/W3/W4/W5/W6, credit-charging, and source-accuracy; open items were test-coverage gaps (since closed: direct `#record_failure`, `docx_to_pdf_job`, and `create_auto_ai_summary_generation` specs added). Round 2 was interrupted. The most important finding came not from the review agents but from Jessica during the run: the W5 status-enum `failed` value was wrong infrastructure — caught and fully reverted (see issue 3, course-correction).

---

## Verification
- 171+ examples, 0 failures across: `ai_job_application_summary`, `ai_job_application_summary_status`, `ai_job_criteria`, `job_application_ai_summary_status`, `job_criteria_lifecycle`, `job_ai_settings`, `textract_result_ai_trigger`, `get_resume_text_from_textract_job`, `generate_ai_job_application_summary_job`, `extract_job_criteria_job`, `find_or_create_ai_job_application_summary_status`, `create_auto_ai_summary_generation`, `docx_to_pdf_job`, `create_ai_credit_balance_transaction`, `queue_bulk_ai_summary_jobs`, `orchestrate`, `score_job_application`, `extract_criteria`, `submit_resume_to_textract` specs.
- Ruby syntax verified on all 13 edited app files. `db/schema.rb` not staged. No stray files.

---

## Specs (brief, at end)
- New: `create_auto_ai_summary_generation_spec.rb`, `docx_to_pdf_job_spec.rb`. Direct `#record_failure` tests (initial_summary_pending→none; current untouched). Updated for new behavior: `ai_job_criteria_spec.rb` (W6 `.with` + non-nil user), `get_resume_text_from_textract_job_spec.rb` (C8 summary persists as failed), `ai_job_application_summary_spec.rb` (W4 broadcast-loop redesign; deleted the obsolete "does not broadcast" block). Your two `find_or_create` TDD tests pass.
- Final verification after the W5 revert: **163 examples, 0 failures** across the AI/criteria/textract/credit spec sweep.
- Pre-existing (not this feature): the branch carries ~16 unrelated pre-loaded spec changes + a regenerated `db/schema.rb` (never staged).

## Deferred (documented, intentionally not built)
Issue-6 stuck-pending sweeper/reaper (the W3 after-commit fix prevents new occurrences at the source; a reaper for already-stuck/infra-lost records needs usage data); issue-3 regenerating-column-clear + S-D/T2 auto-continuation credit (billing blast radius); criteria `latest` vs `latest_succeeded` masking (self-healing, low severity); T8 bulk-backfill idempotency; defensive bridge-selector `order`; dead `ai_bulk_extract.rake`.
