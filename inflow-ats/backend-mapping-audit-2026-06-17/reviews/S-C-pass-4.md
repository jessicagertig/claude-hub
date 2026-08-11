# S-C Pass-4 Adversarial Review — Auto-generate via TextractResult callback

Slice S-C: `TextractResult#queue_ai_summary_job` `after_commit`, ELSE branch (no waiting `textract_processing`/`stale:false` summary), gated on `should_auto_generate_ai_summaries?`. Trace setting check and path to terminal.

Code re-read from scratch:
`app/models/textract_result.rb:7,61-89,98-144`
`app/models/job.rb:159-163,914-922`
`app/services/ai_job_application_action/orchestrate.rb:1-106`
`app/services/ai_job_application_action/summary/generate.rb:6-40`
`app/jobs/generate_ai_job_application_summary_job.rb` (whole)
`app/interactors/validate_ai_summary_generation.rb:1-84`
`app/interactors/find_or_create_ai_job_application_summary_status.rb:1-47`
`app/models/job_application.rb:29-32`

## Per-claim verdicts

### Changelog Trigger C (lines 123-126)

1. "Else-branch validation failure is a SILENT no-op (no summary destroy, no AI_SUMMARY_FAILED broadcast); enqueue guarded only by `if result.success?` with no else (`textract_result.rb:140-143`). The destroy+broadcast path exists only in the `if` (waiting-summary) branch."
AGREE. `textract_result.rb:138-143`: else branch has `return unless should_auto_generate...` (:138), `result = ValidateAiSummaryGeneration.call(...)` (:140), `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?` (:142). No `else`. Destroy+`broadcast_ai_summary_failed` only in the if branch (:132-135).

2. "Else branch enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` with NO `requesting_organization_user_id` (`textract_result.rb:142`), so the auto path never toasts the user."
AGREE. `:142` passes only `textract_result_id: id`. `generate_ai_job_application_summary_job.rb:34` gates `broadcast_completion` on `if requesting_organization_user_id` (nil here → no toast).

3. (MAP-WRONG vs old map) "when NO AiJobApplicationSummary pre-exists, `Orchestrate#call` returns at `orchestrate.rb:16` … `Summary::Generate` … never reached. `generate_ai_summary_with_credit_flow` returns at `textract_result.rb:82`. Auto-generate with no pre-existing summary is a NO-OP dead end: no summary, no credit, no broadcast."
AGREE for the no-pre-existing-summary sub-case. `orchestrate.rb:15` `@job_application.ai_job_application_summaries.order(created_at: :desc).first`, `:16` `return unless @ai_job_application_summary`. `run_summary` (calls `Summary::Generate`, :64) only reached from cases :22-25/:28-34. `textract_result.rb:77` `ai_job_application_summaries.order(created_at: :desc).first` (TextractResult-scoped, `has_many` :5) is nil on the fresh result, `:82` `return unless ai_job_application_summary&.status_succeeded?` returns; `:84` credit never reached. See omission O1 — this is NOT the whole of S-C.

### Part 3 Bridge (line 493)
"`else` auto-generate branch (C/D): `return unless should_auto_generate_ai_summaries?` (:138); validate (:140) → enqueue job with NO requesting user `if result.success?` (:142); validation failure is a silent no-op. With no pre-existing summary, the downstream Orchestrate/credit flow is a NO-OP (S-C)…"
AGREE on all cited lines. Same O1 caveat: "no pre-existing summary" is one sub-case.

### Setting cascade (line 443)
"`Job#should_auto_generate_ai_summaries?` (`app/models/job.rb:914-922`): per-job enum `auto_generate_ai_summaries {default, enabled, disabled}` _prefix:true; `default` falls through to `organization.auto_generate_ai_summaries_enabled`. Checked only at the TextractResult callback else branch (`textract_result.rb:138`)."
AGREE. `job.rb:914-922` exactly: `if auto_generate_ai_summaries_enabled? → true; elsif auto_generate_ai_summaries_disabled? → false; else organization.auto_generate_ai_summaries_enabled`. Enum `{default:0, enabled:1, disabled:2} _prefix:true` at `job.rb:159-163`. Single caller confirmed via grep (only `textract_result.rb:138`).

### Entry guards (line 491)
"Guards: `textract_job_result_text.present?` (:115), `saved_change_to_textract_job_result_text?` (:116), organization present (:119). Branch selector: `ai_job_application_summaries.where(status: :textract_processing, stale: false).first` (job_application-scoped, NO textract_result_id filter, NO explicit order, :121-123)."
AGREE. Verbatim at `textract_result.rb:115,116,119,121-123`.

### Callback registration
`after_commit :queue_ai_summary_job, on: [:create, :update]` (`textract_result.rb:7`).
AGREE.

### State table 5.3 row "regenerating" Reached-by includes "D auto regen, T2 auto-continuation" — out of S-C strict scope but bordering. Not disputing (those are S-D/T2 labels).

## DISPUTES

D1 (state table 5.2, line 534): `extracting` writer `summary/generate.rb:32 / :35-39` "Reached by A,B,C,E, X3 resume." Listing **C** here is internally inconsistent with the map's own RECONCILIATION (line 188) which states for S-C "`Summary::Generate` … never runs." Both cannot be unconditionally true. Resolution: Generate IS reachable on S-C, but ONLY in the pre-existing-non-succeeded-summary sub-case the reconciliation omits (see O1). The map presents S-C as a flat no-op in the changelog/reconciliation while the state table quietly attributes an `extracting` write to C with no qualifier. The C attribution at :534 is correct for the omitted sub-case but contradicts the unqualified no-op framing elsewhere. Mark DISPUTE because the map nowhere reconciles these two statements; a reader following line 188 would conclude C never writes `extracting`, which is false. Contradicting code: `orchestrate.rb:22-26` (`status_pending?`/`status_textract_processing?`/`status_extracting?`/`status_retrying?` → `run_summary`) + `summary/generate.rb:32` (reuse → `:extracting`) / `:35-39` (create → `:extracting`).

## OMISSIONS

O1 — S-C has a THIRD terminal the map never states: **auto path WITH a pre-existing non-succeeded, non-waiting summary advances the pipeline.** The else branch is taken whenever no `textract_processing && stale:false` summary exists (`textract_result.rb:121-123`). A latest summary in `pending`, `retrying`, `extracting`, or a `stale:true textract_processing` state is NOT a waiting summary, so the else branch runs; but `Orchestrate#call` at `:15` selects that summary, `:16` passes, and case `:22-25` (`status_pending?, status_textract_processing?, status_extracting?, status_retrying?`) calls `run_summary` → `Summary::Generate` (`orchestrate.rb:64`), which advances `:extracting → … → succeeded`, charging a credit at `textract_result.rb:84` on success. This is a real S-C path to a SUCCEEDED terminal with credit — directly contradicting the map's blanket "S-C is a no-op dead end." The map's reconciliation (lines 186-190) enumerates only two sub-cases (no summary; stale-succeeded) and omits this one. The state table at :534 implicitly relies on it (attributes `extracting` to C) but never narrates it.

O2 — The entry guard `textract_result.rb:67-68` (`latest_ai_summary = job_application.latest_ai_job_application_summary; return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`) is not mentioned for the S-C entry. On the S-C path with a non-stale succeeded latest summary, `generate_ai_summary_with_credit_flow` returns at :68 BEFORE Orchestrate — a distinct early-exit terminal. (Note: this is the same line the map discusses for bulk at line 111 and S-D at 133, but it is never tied to the auto/S-C job entry, which is where the auto-enqueued job lands.)

O3 — `should_auto_generate_ai_summaries?` org fallback target `organization.auto_generate_ai_summaries_enabled` is cited (line 443 says "seeded false", `org.rb:965-967`) but I did not independently re-open `org.rb:965-967` in this pass; flagging the org-method line cite as unverified-by-me (default-to-skepticism). The 3-state job cascade itself (`job.rb:914-922`) is verified.

O4 — `generate_ai_summary_with_credit_flow` on the S-C path calls `find_or_create_ai_job_application_summary_status` (:70) and `set_initial_summary_pending` (:72) BEFORE Orchestrate. In the no-pre-existing-summary sub-case both no-op (status row already `none` with nil summary → `find_or_create_…:14` false, no write; `set_initial_summary_pending` returns at `:101` since `latest_summary` nil). The map covers the no-op pass-through generally (line 159/561) but does not state it explicitly for the S-C job entry sequence.

## clean = false
Reason: D1 (internal contradiction) + omissions O1-O4. O1 is the substantive one — the map's "S-C = flat no-op dead end" framing is incomplete; a pre-existing pending/retrying/extracting summary lets the auto path reach `succeeded` and charge a credit.
