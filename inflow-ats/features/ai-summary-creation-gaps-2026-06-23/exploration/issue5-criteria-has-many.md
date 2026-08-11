# Finding: issue5-criteria-has-many (recovery agent, markdown)

## VERDICT
**has_many is sufficient AS A REFACTOR — but is NOT the fix for Issue 5's incident.**

### (A) Ripple/consistency audit — CLEAN
- `Job has_many :ai_job_criteria, class_name: 'AiJobCriteria'` (job.rb:52); no `counter_cache:`/`dependent:`/`inverse_of:`. `AiJobCriteria belongs_to :job` (ai_job_criteria.rb:4).
- Unique index DROPPED → non-unique (`20260622204646_*`; schema:190). DB now permits multiple rows/job — schema + association agree.
- Readers all collection-aware: `latest_ai_job_criteria` (job.rb:688-690, newest ANY status), `latest_succeeded_ai_job_criteria` (job.rb:692-694, newest succeeded). `orchestrate.rb:74` + `score_job_application.rb:19` use `latest_ai_job_criteria`. NO singular bare-`.ai_job_criteria`-as-one-record reader survives.
- Writers: only two creation sites, both `ai_job_criteria.new(status: :pending)` + save (job.rb:703 auto_extract, job.rb:720 extract). Old in-place `update_columns(status: :pending)` "reset" path is GONE.
- `_ids`/`criterium` quirk: appears NOWHERE in code (only the explanatory comment ai_job_criteria.rb:32-36). No `accepts_nested_attributes_for`. No ripple.
- Serializers: zero `AiJobCriteria` exposure (the `criteria_results` serializer attr is `AiJobApplicationSummary#criteria_results`, a jsonb column — NOT criteria). FE: zero references. No ripple.
- `jobs.ai_job_criteria_generations_count` (schema:904) + `jobs.internal_job_criteria` (schema:905) = ORPHAN columns, "logic not yet wired" (commit 458607bb6), zero readers/writers. Inert, not a bug. (The counter_culture that commit DID wire is `AiJobApplicationSummaryStatus → jobs.ai_job_application_summaries_count`, a different record.)
- `resume_waiting_summaries` iterates `job.ai_job_application_summaries` (summaries, not criteria) — unaffected by cardinality.
- MAP STALE on cardinality (lines 494-499, 624): describes the old has_one reset writer at job.rb:696 which no longer exists. Expected.

### (B) Failed-criteria behavior — overwrite is now structurally impossible
- Re-trigger creates a NEW record; a prior `failed` row is left fully intact. Overwrite failure mode GONE.
- Readers pick newest by created_at. After "failed(old) then succeeded(new)" → readers pick the new succeeded. Correct.
- **DELTA-1 (LOW, REAL):** reverse case — `succeeded`(old) then `failed`(new): `latest_ai_job_criteria` returns the newer FAILED, masking the older SUCCEEDED. `orchestrate.rb:74-82` and `score_job_application.rb:19-46` then RE-EXTRACT (build a new pending row) instead of using the good older criteria. Effect: redundant ExtractJobCriteriaJob + OpenAI calls + delay; NEVER a wrong score or crash (both readers gate on status before reading `.criteria`); self-heals. `latest_succeeded_ai_job_criteria` exists but is DEAD CODE (zero callers) — apparent intended remedy, unwired. CAUTION: naive switch to latest_succeeded could serve STALE criteria after a description edit (handle_description_change deliberately re-extracts on meaningful edits) — a real fix needs freshness/version logic. Arises when a description edit or transient provider error produces a newer failed row after a succeeded one.

### (C) Incident reconciliation — root cause is STUCK-PENDING POISON, not overwrite
- Overwrite (has_one) would produce a lost-failure, NOT "still pending." has_many prevents overwrite but that's a DIFFERENT bug.
- The incident ("still pending + summary stuck + manual generate did nothing") = stuck-pending poison: a `pending` row's ONLY advancer is its own ExtractJobCriteriaJob; if that job never advances it (lost/never-run — and see orchestrator's V1 enqueue-in-transaction race), the row sits pending forever, and the pending-guard (job.rb:701/718) then blocks EVERY future extract_job_criteria/auto_extract_job_criteria (incl. the manual generate she clicked). resume_waiting_summaries only fires on succeeded → never → summary parked at awaiting_job_criteria forever.
- **has_many does NOT fix this — the pending-guard + non-self-healing pending state is byte-identical before and after the refactor.**

### (D) Pre-loaded spec coverage gap
All 5 specs exercise ≤1 AiJobCriteria row per job. UNTESTED: multiple rows/job (the refactor's premise), latest/latest_succeeded selection, failed-then-retrigger preservation, the (B) DELTA, retry_on exhaustion→failed, the pending-poison guard. The has_many semantics the refactor introduced are NOT tested.

### (E) Real DELTAs, ranked
1. **DELTA-2 / stuck-pending poison (HIGH, the actual incident):** unaddressed by has_many. Root cause = the enqueue-in-transaction race (V1, orchestrator-verified: auto_extract_job_criteria runs in Job before_update txn, Rails 6.1 no enqueue_after_transaction_commit) + lost/never-run job (V2) + the pending-guard amplifier. Fix direction: enqueue ExtractJobCriteriaJob AFTER the Job commits (move to after_commit), + optionally a sweeper for already-stuck/V2/V3 (sweeper DEFERRED per KICKOFF issue 6).
2. **DELTA-1 / latest vs latest_succeeded (LOW, real):** redundant re-extraction when a newer non-succeeded row masks an older succeeded; self-healing; latest_succeeded_ai_job_criteria is dead code; a fix needs freshness logic to avoid stale criteria after description edits. NOTE/decision.
3. **DELTA-3 / orphan columns (LOW housekeeping):** ai_job_criteria_generations_count, internal_job_criteria inert. Not a bug.

### Reproductions (orchestrator to run)
- **R1** (A+B core): create failed row A; `job.extract_job_criteria` → assert count==2, latest is new pending, A untouched (no overwrite).
- **R2** (DELTA-1): create succeeded(old) + failed(new); assert `latest_ai_job_criteria`==failed_new, `latest_succeeded_ai_job_criteria`==succeeded_old; assert ScoreJobApplication re-extracts despite valid succeeded criteria existing.
- **R3** (DELTA-2/incident): create pending row; assert `job.extract_job_criteria` and `job.auto_extract_job_criteria` do NOT change count (poison guard job.rb:701/718).
