# Verify: AiJobCriteria — data model + status transitions + resume_waiting_summaries re-trigger

**Verdict: CLEAN**

Files checked:
- OLD: `backend-flow-map-2026-06-17.md` (X3 changelog 260-274; S-E cross-refs 222/228/229/235; Parts 557-561, 595-600, 659/670, 693-704, 828, 846)
- NEW: `backend-flow-map-2026-06-22-neutral.md` (X3 section 397-407; cross-refs 57/97-107/319; Parts 467/483/494-499/539/624)

## CHECK 1 — Fact preservation

Every load-bearing fact + citation in OLD appears in NEW:

| Fact | OLD cite | NEW cite |
|---|---|---|
| after_commit `resume_waiting_summaries` on:[:update], guard `saved_change_to_status? && status_succeeded?` | 260, 559 (`ai_job_criteria.rb:17,22`) | 398, 104 |
| re-enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id:)`, no stale filter, no requesting user | 261 (`:24-27`) | 400, 107 |
| `succeeded` only callback-firing transition; uses `.update` deliberately (in-code comment); all others `update_columns` | 262 (`extract_criteria.rb:132-140`) | 107, 407 |
| idempotency: `:22` requires `saved_change_to_status?` | 263 | 400 |
| succeeded advance path: credit-flow `:32`; `:68` guard; `:35` branch; `:70`/redundant `:72`; `:76` true → run_scoring `:77`/run_integration `:78` → succeeded; `:82`/`:84` charge credit | 264 | 343, 404, 349 |
| `CreateAiCreditBalanceTransaction.call` charges credit `:84` | 264 | 349, 404, 410 |
| failed criteria = no advancing actor unless later Orchestrate/ScoreJobApplication re-invokes `extract_job_criteria`; failed via `update_columns` | 265, 704 | 407, 467, 499 |
| `retrying` `:146`/`:147` + retry_on attempts:3 (`extract_job_criteria_job.rb:5`) → succeeded or exhaust `:9`; only AiJobCriteria status with built-in re-driver | 266, 701 | 407, 498 |
| `score_job_application.rb:46` concrete loop-closing re-trigger (failed `:44`, reset `:45`, `extract_job_criteria` `:46`) | 267, 267 | 379, 407, 499 |
| benign empty fan-out: zero awaiting summaries → `find_each` `:24` iterates nothing | 269 | 400 |
| nil textract_result_id no-op at `generate_…job.rb:30` (find_by `:25` nil), before `:32`/Orchestrate | 270 | 403, 356 |
| cross-application fan-out via `has_many through: :job_applications` (`job.rb:51`), all job_applications | 271, 560 | 400 |
| stale summaries included; resumed run reads `latest_ai_job_application_summary` (possibly newer) | 272 | 404 |
| newest-summary re-selection fork: `latest_ai_job_application_summary`/`orchestrate.rb:15` order desc; awaiting-is-newest advances `:35`; different newer succeeded-non-stale → `:68` guard returns, awaiting not advanced | 273, 561 | 404 (`order(created_at: :desc)` def at 112) |
| no completion toast on resumed succeeded run; `:34` `broadcast_completion … if requesting_organization_user_id` skipped | 274, 235, 561 | 405, 356 |
| requesting user preserved into first enqueue (`textract_result.rb:130`) dropped across criteria-wait | 235 | 405 |
| status-row desync at awaiting_job_criteria rest: row stays `initial_summary_pending`; `update_summary_status_record` only on `status_succeeded?` (`ai_job_application_summary.rb:69`) | 228, 828 | 482, 539, 467 |
| `orchestrate.rb:80 extract_job_criteria` only kicks off, does not advance | 229, 550 | 375 |
| BROADCAST_STATUSES omits awaiting_job_criteria + retrying; `orchestrate.rb:72` transition emits no broadcast | 222, 583 | 57, 467 |
| criteria status-writer table (pending create `job.rb:699-700`, reset `:696`, in_progress `extract_criteria.rb:28`, succeeded `:132-140`, retrying `:146`/`:147`, failed `:32,62,122,151,155`/`score_job_application.rb:44`/`extract_job_criteria_job.rb:9,28`) | 697-702, 846 | 494-499, 407, 624 |
| AiJobCriteria columns: criteria(jsonb), status, metadata, error_message, job_id | 599 | 103 |
| `update.rb:46-48` enum/order: pending:0,in_progress:1,succeeded:2,failed:3,retrying:4 | 693 | 490 |

No dropped facts. No altered citations or flipped conditions. Line numbers cross-checked (e.g. `:68`, `:70`, `:72`, `:76`, `:82`, `:84`, `:24-27`, `:30`, `:34` all match between OLD and NEW).

Note: OLD :268 is a meta-NOTE reconciling the map's own prior-pass `:198`/`:224` "guard does not fire" framing; the underlying code fact (advance-vs-not fork) is fully preserved in NEW :404. Removal of the prior-pass reconciliation prose is de-duplication of internal-map commentary, not a code-fact drop. NEW adds the `summary_text`/`headline` already-persisted fact (407, 467) which OLD's X3 section lacks — an addition, not a drop.

## CHECK 2 — Neutrality

NEW X3 section and all criteria-topic lines scanned for banned vocab (dead end, stuck, broken, orphan, no-op, silently, hazard, fails to, MAP-WRONG, never recovers, incorrect, problem, defect, wrong, concerning, matters, stranded, desync) and subtler framing. None present in the topic text.

OLD's defect-framing ("a silent dead end", "stranded-awaiting-row terminal", "NEVER advanced", "silently dropped", "dead end", judgmental ALL-CAPS) has been neutrally reframed in NEW:
- 404 "the awaiting row is not advanced on this run" (was OLD 273 "NEVER advanced — a silent dead end")
- 405 "no `AI_SUMMARY_COMPLETE` toast … loses the requesting user" (was OLD 274/235 "NO … toast", "silently dropped")
- 499 "an `awaiting_job_criteria` summary depending on it advances only when a later … pass re-invokes" (was OLD 704 "dead end")

The only "orphan" occurrences in NEW are the allowed method name `cleanup_orphaned_summary` (149, 232, 449, 456, 630) — unrelated to this topic and explicitly allowed.

No neutrality issues.
