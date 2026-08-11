# Round 1 — Angle 1: Zero-criteria review guard — entry-point completeness and predicate semantics

## Verified against source (all at worktree HEAD 05c9513ef)

**Independent entry-point re-trace** — ran the required greps (`GenerateAiJobApplicationSummaryJob.perform_later|generate_ai_summary_with_credit_flow|CreateAiSummaryGeneration.call|CreateBulkAiSummaryGeneration.call|auto_generate_ai_summary_if_enabled|QueueBulkAiSummaryJobs.call|Orchestrate.new` over `app/ lib/`, non-spec). Complete hit list:

- `ai_job_application_summaries_controller.rb:17` — CreateAiSummaryGeneration.call, behind ValidateAiSummaryGeneration at :8 → SPEC 6.1 entry 1 ✓
- `bulk_ai_job_application_summaries_controller.rb:13,37` — QueueBulkAiSummaryJobs.call → `bulk_generate_ai_summaries_job.rb:59` (per-record ValidateAiSummaryGeneration), :74 (CreateBulkAiSummaryGeneration), :80 (funnel) → entry 2 ✓
- `job_application.rb:175` (enqueue_new_job_application) and `job_applications_controller.rb:118` → `auto_generate_ai_summary_if_enabled` (job_application.rb:183-188, ValidateAutoAiSummaryGeneration at :186) → entries 3, 4 ✓
- `textract_result.rb:130` (manual-waiting branch, validator at :128) and :144 (auto branch, validator at :142) inside `queue_ai_summary_job` :116-146 → entry 5 ✓
- `ai_job_criteria.rb:25` — `resume_waiting_summaries` :21-30, no validator, fires only when criteria just transitioned to succeeded (guard definitionally false; resumed reviews are not new) → entry 6 ✓
- `create_ai_summary_generation.rb:71` — direct enqueue, behind a validator on every calling path (controller entry 1 validates at :8; auto entries 3/4 validate at job_application.rb:186; bulk does not call this interactor) ✓
- Funnel: `textract_result.rb:61-91`, called from `generate_ai_job_application_summary_job.rb:32` and `bulk_generate_ai_summaries_job.rb:80`; `Orchestrate.new` only at textract_result.rb:113 (inside the funnel) → entry 7 ✓

No other production creation/start paths found. **SPEC 6.1 table is complete.**

**Guard placement (SPEC 6.2):**
- ValidateAiSummaryGeneration: description fail at :29 — spec inserts after it ✓; message single-quoted, matches the QueueBulkAiSummaryJobs site verbatim ✓; safe-nav `@job_application.job&.` ✓.
- ValidateAutoAiSummaryGeneration: description fail at :18 — spec inserts after it ✓; silent decline matches existing auto-path convention (credits/description) ✓.
- QueueBulkAiSummaryJobs: credits fail at :18 — spec inserts after ✓; `context.job&.` safe-nav keeps existing job-less callers working ✓; both bulk controller actions hold `@job` (:9, :33) and can pass `job: @job` (:13-17, :37-43) ✓; failure renders via `render_general_errors([result.error])` (:26, :52) → synchronous toast, as the spec claims ✓.
- Funnel guard: `generate_ai_summary_with_credit_flow` early return at :68, `extract_job_criteria_if_needed` at :70 — spec places the guard between them; ordering rationale (blocked review must not re-trigger extraction) verified real ✓.

**Predicate semantics:**
- Three writer strings verified EXACT: `'No criteria sections found in job description'` (extract_criteria.rb:62), `'No criteria extracted from job description'` (extract_criteria.rb:122), `'Criteria array is empty'` (score_job_application.rb:43). All three use `update_columns` with `status: :failed` — `zero_criteria_failure?` (`status_failed? && ZERO_CRITERIA_ERROR_MESSAGES.include?(error_message)`) matches all three and only these ✓.
- Succeeded rows always have ≥1 criterion: `non_duplicates.empty?` guard at extract_criteria.rb:121-124 precedes the succeeded `update` at :132-142 ✓.
- Non-member failure messages land generic: `'Job description is blank'` (:32), `"Failed to parse AI response: …"` (:148-151), StandardError (:152-155), retry-exhaustion (extract_job_criteria_job.rb:9, writes `error&.message`) ✓.
- `Job#zero_criteria_extraction_failure?` reads `latest_ai_job_criteria` (any status, job.rb:688-690 `order(created_at: :desc).first`) — deliberately NOT latest-terminal; a new pending row makes the predicate false and reviews start and wait via `awaiting_job_criteria` (score_job_application.rb:21-30, orchestrate.rb check_criteria_and_score, ai_job_criteria.rb:21-30). Confirmed this must NOT be "fixed" to latest-terminal.
- NOT placed in Orchestrate/ScoreJobApplication/CreateAiSummaryGeneration/CreateBulkAiSummaryGeneration — spec 6.2 note verified; mid-pipeline `extract_job_criteria` calls at score_job_application.rb:23/:45 and orchestrate.rb:80 are pre-existing behavior for in-flight reviews, correctly out of scope.
- SPEC 6.4: `resume_waiting_summaries` fires only on succeeded (ai_job_criteria.rb:22) — waiting summaries stay waiting on a zero-criteria completion; existing behavior, untouched ✓.

## Taken on trust from the spec
Nothing load-bearing; all claims in sections 4.2, 4.3, 6.1-6.4 were re-verified above.

## Findings

No issues found.

## Amendments Applied

None (this angle).
