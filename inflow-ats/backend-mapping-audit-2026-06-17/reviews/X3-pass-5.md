# Adversarial Review — Slice X3 (AiJobCriteria re-trigger) — Pass 5

**Date:** 2026-06-22
**Candidate map:** `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/backend-flow-map-2026-06-17.md`
**Code re-read from scratch.** Trace chain:
`ai_job_criteria.rb:17,22-28` → `generate_ai_job_application_summary_job.rb:24-32` → `textract_result.rb:61-89` (`generate_ai_summary_with_credit_flow`) → `textract_result.rb:110-112` (`generate_ai_summary`) → `orchestrate.rb:5-83` → `extract_criteria.rb:28-156` → `extract_job_criteria_job.rb:5-29` → `score_job_application.rb:19-47` → `job.rb:51-52,688-704` → `ai_job_application_summary.rb:10-23,69-102` → `db/schema.rb:147-186`.

---

## Verdicts on candidate-map X3 statements

### Map :195 — `resume_waiting_summaries` after_commit on:[:update], guard `saved_change_to_status? && status_succeeded?`; re-enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id:)` for each awaiting summary, no stale filter, no requesting user
**AGREE.** `ai_job_criteria.rb:17` `after_commit :resume_waiting_summaries, on: [:update]`; `:22` `return unless saved_change_to_status? && status_succeeded?`; `:24` `.where(status: :awaiting_job_criteria)` (no stale filter); `:25-27` enqueues with only `textract_result_id:`.

### Map :196 — `succeeded` is the ONLY callback-firing transition; every other status write uses `update_columns`; succeeded write uses `.update` deliberately (`extract_criteria.rb:132-140`, in-code comment)
**AGREE.** Exhaustive write census (grep + read): only `.update` status write on AiJobCriteria is `extract_criteria.rb:140` (`unless @ai_job_criteria.update(update_params)`, params at `:132-136`, comment `:138-139`). All others are `update_columns`: `job.rb:696` (pending reset), `extract_criteria.rb:28` (in_progress), `:32/:62/:122/:151/:155` (failed), `:146` (retrying), `extract_job_criteria_job.rb:9/:28` (failed), `score_job_application.rb:44` (failed). The pending CREATE (`job.rb:699` `AiJobCriteria.new(...status: :pending)` + save) cannot fire the `on: [:update]` callback.

### Map :197 — idempotency: `saved_change_to_status?` also required, so an `.update` on an already-succeeded row not changing status would not re-fire
**AGREE.** `ai_job_criteria.rb:22` literally `return unless saved_change_to_status? && status_succeeded?`.

### Map :198 — succeeded-firing advance path: re-enqueued job runs `generate_ai_summary_with_credit_flow` (`:32`); awaiting summary not succeeded so `textract_result.rb:68` guard does not fire; Orchestrate hits `:35` awaiting branch → check_criteria_and_score → re-executes `:70` and redundant `:72` → `:76` true → run_scoring/run_integration → succeeded; `:82` passes and `:84` charges a credit. pending/in_progress/retrying never fire the callback.
**AGREE (with a scoping caveat recorded as an omission).** Verified: `generate_ai_job_application_summary_job.rb:32` `textract_result.generate_ai_summary_with_credit_flow`; `textract_result.rb:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`; `generate_ai_summary` → `orchestrate.rb:111`; `orchestrate.rb:35` `when @ai_job_application_summary.status_awaiting_job_criteria?` → `:36 check_criteria_and_score`; `:70 return unless summary_complete?`; `:72 update(status: :awaiting_job_criteria)`; `:76 if ai_job_criteria&.status_succeeded?` → `:77 run_scoring` + `:78 run_integration`; `textract_result.rb:82 return unless ...status_succeeded?` then `:84 CreateAiCreditBalanceTransaction.call`. CAVEAT: both `textract_result.rb:67` (`latest_ai_job_application_summary`, `job_application.rb:31` `order(created_at: :desc)`) AND `orchestrate.rb:15` (`order(created_at: :desc).first`) select the NEWEST summary on the job_application, NOT the specific re-enqueued awaiting summary. The chain in :198 holds only when the awaiting summary IS the newest. If a newer succeeded non-stale summary exists, `:68` DOES fire and the awaiting summary never advances. See omission O1. (Counted AGREE because :198 is explicitly the advance/“SUCCEEDED case” narrative and the contradicting case is left to the reader.)

### Map :199 — dead end: an awaiting summary whose criteria ends `failed` has no advancing actor unless a later Orchestrate/ScoreJobApplication pass re-invokes `job.extract_job_criteria`; the failed transition itself never resumes it (all failed writes use update_columns)
**AGREE.** Failed writes (`extract_criteria.rb:32/62/122/151/155`, `extract_job_criteria_job.rb:9/28`, `score_job_application.rb:44`) all `update_columns` → no `resume_waiting_summaries`. Re-invocation routes exist at `orchestrate.rb:80` (`extract_job_criteria unless pending/in_progress`) and `score_job_application.rb:25-26,46`, consistent with the map.

### Map :200 — benign empty fan-out: succeeded with zero awaiting summaries → `find_each` iterates nothing
**AGREE.** `ai_job_criteria.rb:24` `.where(status: :awaiting_job_criteria).find_each` over an empty relation no-ops.

### Map :201 — nil textract_result_id no-op site: `ai_job_criteria.rb:26` passes nullable `textract_result_id`; when nil the no-op is at `generate_ai_job_application_summary_job.rb:30` (`return unless textract_result`), before Orchestrate constructed
**AGREE.** `db/schema.rb:149` `t.bigint "textract_result_id"` (nullable). `generate_ai_job_application_summary_job.rb:25` `TextractResult.find_by(id: textract_result_id)`; `:30 return unless textract_result` precedes `:32`. Orchestrate is only constructed inside `generate_ai_summary_with_credit_flow` → `generate_ai_summary` (`textract_result.rb:111`), never reached.

### Map :202 — cross-application fan-out: `job.ai_job_application_summaries` is `has_many through: :job_applications` (`job.rb:51`); one criteria succeeded re-enqueues for EVERY awaiting summary across ALL job_applications (find_each)
**AGREE.** `job.rb:51` `has_many :ai_job_application_summaries, through: :job_applications`. `job.rb:52` `has_one :ai_job_criteria` (one criteria/job). `find_each` (`ai_job_criteria.rb:24`).

### Map :203 — stale summaries included: `ai_job_criteria.rb:24` filters on status only (no stale filter), so a stale:true awaiting summary is re-enqueued; on the resumed run `generate_ai_summary_with_credit_flow:67` reads `latest_ai_job_application_summary` (possibly a different, newer summary)
**AGREE.** No stale filter at `:24`. `textract_result.rb:67` reads `job_application.latest_ai_job_application_summary` (`job_application.rb:31`, newest), independent of which summary was re-enqueued.

### Map :483-485 (Part-7 detail block) — restates :17/:22 guard; fan-out across all job_applications; nil textract_result_id no-op at `:30`; succeeded run advances via `:35` branch (re-executing `:70` + redundant `:72`) → `:76` → run_scoring/run_integration → succeeded, charging at `textract_result.rb:84`; pending/in_progress/retrying/failed never fire; succeeded with zero awaiting is benign empty find_each
**AGREE.** Consistent with all lines verified above.

### Map :617-628 (5.4 AiJobCriteria.status table) — pending(create) `job.rb:699-700` none(on:create); pending(reset) `job.rb:696` update_columns none; succeeded `extract_criteria.rb:132-140` **fires resume_waiting_summaries** RESTING; failed `extract_criteria.rb:.../score_job_application.rb:44/extract_job_criteria_job.rb:9,28` update_columns none RESTING; dead-end note
**AGREE.** All write sites and callback-firing characterizations verified against code.

### Map :168 / :172 — BROADCAST_STATUSES omits awaiting_job_criteria & retrying (no broadcast into awaiting); update_summary_status_record only on status_succeeded? so status row stays initial_summary_pending during the awaiting rest
**AGREE (X3-relevant context).** `ai_job_application_summary.rb:23` BROADCAST_STATUSES excludes `awaiting_job_criteria`,`retrying`; `:100-102` broadcast_status_change guarded by BROADCAST_STATUSES; `:69` `return unless saved_change_to_status? && status_succeeded?`.

---

## Omissions (X3)

**O1 — `textract_result.rb:68` guard CAN fire on the resumed run when a newer succeeded non-stale summary exists.**
The X3 section (`:198`) states flatly that on the resumed run "the awaiting summary is not succeeded so the `textract_result.rb:68` guard does not fire." But `generate_ai_summary_with_credit_flow` never reads the re-enqueued awaiting summary; `:67` reads `job_application.latest_ai_job_application_summary` (`job_application.rb:31`, `order(created_at: :desc)`) and `orchestrate.rb:15` likewise picks `order(created_at: :desc).first`. When the latest summary on that job_application is a DIFFERENT summary that is `succeeded` and not `stale`, `:68 return` fires and the awaiting summary is NEVER advanced by this re-trigger — a silent dead end for that awaiting row. The map flags the "different newer summary" read only at `:203` (stale context) and does not connect it to the guard-fires / awaiting-row-stranded outcome in the X3 narrative.

**O2 — Resumed succeeded run produces NO completion toast.**
The re-enqueue (`ai_job_criteria.rb:25-27`) passes only `textract_result_id:` and no `requesting_organization_user_id`. On the resumed run reaching `succeeded`, `generate_ai_job_application_summary_job.rb:34` (`broadcast_completion(...) if requesting_organization_user_id`) is skipped (nil), so the user gets NO `AI_SUMMARY_COMPLETE` toast for a criteria-resumed completion. The map notes "no requesting user" only as a re-enqueue argument fact (`:195`); the user-visible no-toast consequence on the resumed terminal is not stated.

**O3 — Orchestrate selects the latest summary, not the re-enqueued one (mechanism not stated in X3).**
Neither `:198` nor `:485` states that `orchestrate.rb:15` re-selects `@ai_job_application_summary` as `@job_application.ai_job_application_summaries.order(created_at: :desc).first`. The re-enqueued job carries only `textract_result_id`; the awaiting summary that triggered the fan-out is never passed through. The whole resumed-run branch selection depends on this newest-wins re-selection (root cause of O1). This is the structural mechanism behind the X3 advance/dead-end fork and is omitted from the X3 prose.

---

## Conclusion
Every explicit X3 map statement is AGREE against current code. Three omissions (O1-O3) concern the newest-summary re-selection in `generate_ai_summary_with_credit_flow`/`Orchestrate` and its consequences (guard can strand the awaiting row; no toast). **clean = false** (omissions non-empty).
