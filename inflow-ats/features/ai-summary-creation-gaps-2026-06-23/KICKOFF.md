# Kickoff — AI Summary Creation Gaps + docx→Textract Trigger (2026-06-23)

Investigation → spec → plan → implementation kickoff. Source of truth is the verified backend flow map. **Verify everything against the map and live code; never reason from assumptions.**

## Working mode — exhaustive, autonomous, ALL NIGHT

You have all night. Work continuously and autonomously until LIFECYCLE phase 7 is complete OR it is ~9am — whichever comes first. Do not stop early. Do not ask permission. Do not hand back a shallow answer.

- **Check the time; do not stop early.** Whenever you feel like wrapping up, print the current time (`date`). If it is before ~9am there is NO reason to stop — keep going: dig deeper, advance to the next phase, harden what you have.
- **Do NOT wait for human approval.** Jessica is asleep. The LIFECYCLE's human-checkpoint gates between phases are replaced tonight by rigorous ADVERSARIAL self-review — spawn agents to attack your own findings, spec, plan, and code — then proceed on your own judgment. Never pause at a gate waiting for a reply.
- **No shallow verdicts. Investigate exhaustively.** Every issue gets a full investigation, never a binary "yes it happened / no it didn't / maybe that fixed it." Jessica's statements are HYPOTHESES she is handing you ("I'm just proposing a theory… I don't know what the fuck happened"), NOT answers. PROVE or DISPROVE each against evidence: trace every identifier to its definition, and where reading code is not enough, REPRODUCE — write and run tests, exercise the path in the rails console or the app, inspect real records. Figure it out.
- **This prompt is a starting point, not a fence.** Chase anything related you uncover. If a guardrail below seems to block real investigation, the investigation wins — only the two hard limits are absolute.
- **Don't stop on a blocker.** Investigate it, document it, route around it, keep working. Stopping to wait is the wrong move tonight.
- **The only hard limits:** scope ends at the end of LIFECYCLE phase 7 (do NOT start phase 8 / QA), and time ends ~9am. If you finish phase 7 before 9am, keep hardening within scope (more adversarial review, deeper gap investigation, more test coverage) — do not start phase 8, do not stop. Near 9am, stop and leave a clear status: what you found, what you did, what's verified vs open.

## Source of truth — the map

`/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/backend-flow-map-2026-06-22-neutral.md`

- This is the NEUTRAL, independently-verified map (neutrality + fact-preservation checked end-to-end across two adversarial passes). Use ONLY this file.
- Do NOT use `backend-flow-map-2026-06-17.md` (older, defect-framed) or `textract-ai-summary-map-6-6-2026-COPY.md` (older reference).
- It covers: Textract (`TextractResult`), AI summary (`AiJobApplicationSummary`), AI bulk (T8/S-B), the `AiJobApplicationSummaryStatus` display-state table, `AiJobCriteria`, and the create/transition lifecycle of all four records.
- **Read first:** Overview; Data models (all four records); The bridge (`TextractResult#queue_ai_summary_job`); The AI pipeline (especially "Auto branch (else) — three downstream cases"); State-transition tables; the `AiJobApplicationSummaryStatus` dedicated section; Frontend consumers.

The map is a snapshot (branch as of 2026-06-22). It is verified, but for any change you are about to make, re-confirm the specific behavior against live code in `/Users/jessica/wrk/wrk-corp/inflow-ats`. The map anchors you; the code is what you change.

## Rules of engagement

- **Verify, don't assume.** Every claim = a map section and/or `file:line` in code. Use EXACT identifiers (`AiJobApplicationSummary`, `AiJobApplicationSummaryStatus`, `textract_processing`, `TextractResult.textract_job_status`), never paraphrases.
- **Separate three things per issue:** CURRENT (what the code does now, per map + `file:line`) / INTENDED (the desired behavior) / DELTA (the verified gap). A "gap" is a delta you proved against code, not a vibe.
- **A resting state that a later action in the codebase will advance is NOT a bug/gap.** Confirm whether a later actor resolves it before calling anything a gap.
- **Check before you build.** Before proposing to create any file/job/class, verify it does not already exist (grep + map). See issue 2.
- **Find the analog.** Before designing a fix, find existing code that already does the same thing and mirror its structure.

## Method (per issue)

For each issue, and anything related you uncover: propose solution(s) → trace the side effects of implementing them → audit those side effects against the map → report findings. Then draft a plan and adversarially review the plan against (a) codebase conventions and (b) the map.

## Issues

### 1. No `AiJobApplicationSummary` created on auto-generate when Textract isn't ready
- **Observed:** an application came in with auto-generate ON; its `TextractResult` was `failed`; there was NO `AiJobApplicationSummary` record at all; the `AiJobApplicationSummaryStatus` row existed (as expected).
- **Intended:** auto-generate ON ⇒ create an `AiJobApplicationSummary`; if Textract isn't ready ⇒ that summary is `textract_processing`. Jessica's belief: this should happen for EVERY auto-gen submission, immediately, before Textract resolves — and she suspects the code does not do this at all today (it was not designed in; "maybe I'm wrong, I don't remember"). Confirm whether ANY path creates the summary on the auto-gen entry before Textract resolves; if none does, this is likely NEW behavior to add (mirror the S-A analog below).
- **Concrete incident:** a job-board submission that happened to be a Docx (see issue 2). Auto-gen never created the summary, let alone in `textract_processing`.
- **Map anchors:**
  - "The AI pipeline → Auto branch (else) — three downstream cases", case 1: no pre-existing summary ⇒ `Orchestrate#call` returns at `orchestrate.rb:16` ⇒ no summary, no credit, no broadcast. (The map confirms the auto path creates no summary when none pre-exists.)
  - `Summary::Generate` (`summary/generate.rb:35-39`) is the SOLE first-summary creator, reached only via `run_summary` AFTER the `:16` guard — so the auto/bridge path never reaches it when no summary pre-exists.
  - **Analog to mirror:** T9 / S-A `CreateAiSummaryGeneration` no-`TextractResult` path BUILDS a `textract_processing` summary (`create_ai_summary_generation.rb:47-53`). The auto/bridge path does not. The fix likely mirrors this analog.
  - Also confirm where the eager `AiJobApplicationSummaryStatus` row is created (`enqueue_new_job_application` → `find_or_create_ai_job_application_summary_status`, `job_application.rb:170`) and whether a summary should be created on the same path. (Related to issue 5.)

### 2. Chain Textract submission to `DocxToPdfJob` success (docx case)
- **Confirmed by Jessica — the job EXISTS.** `DocxToPdfJob` kicks off after job-application submission for every resume file; it RETURNS early when the file is already a PDF and only PROCESSES (converts) when the file is a Docx, producing `resume_docx_to_pdf` (`job_application.rb:165-166`; `SubmitResumeToTextract` prefers `resume_docx_to_pdf`, `submit_resume_to_textract.rb:15`). So this is NOT "build a job" — it is "add a trigger linkage."
- **Hard constraint:** Textract only accepts PDFs. A docx must be converted before Textract can run on it.
- **The gap:** Textract submission and `DocxToPdfJob` are both `perform_later` with no ordering guarantee. For a docx, `SubmitResumeToTextract` can run before the converted PDF (`resume_docx_to_pdf`) is attached — so Textract has no PDF to send and the docx path fails / produces no usable `TextractResult`.
- **Direction (Jessica's):** chain `SubmitResumeToTextract` to fire from `DocxToPdfJob`'s success (once the converted PDF is attached), rather than independently at submission. Verify `DocxToPdfJob`'s body, its early-return-on-PDF, and how `SubmitResumeToTextract` selects `resume_docx_to_pdf` vs `resume`. Note the PDF case must still trigger Textract directly (only the docx case waits on conversion).

### 3. Gap — `regenerating` / `initial_summary_pending` states
- **Map anchor:** `AiJobApplicationSummaryStatus` → "Windows where the row differs from the latest summary":
  - #2: summary ends `failed`/`retrying` ⇒ `update_summary_status_record` does not run ⇒ row stays `initial_summary_pending`/`regenerating` (no `failed` value in the enum).
  - #3: `regenerating` is a status-only `update_columns` ⇒ old `score_percentage`/`headline`/`integrated_role_analysis` persist.
  - #4: S-D / T2 auto-continuation ⇒ row stays `regenerating` with prior data.
- Investigate solutions; confirm each is a real DELTA (and not later-resolved by S-A/S-B regeneration, which the map says recovers the row to `current`).

### 4. Gap — visibility while `AiJobApplicationSummary` and `AiJobCriteria` are pending ("how do we even know something is happening")
- **Map anchors:** Frontend consumers (F1); `AiJobApplicationSummary::BROADCAST_STATUSES` EXCLUDES `awaiting_job_criteria` and `retrying` (`ai_job_application_summary.rb:23`) ⇒ transitions into those broadcast nothing; the status row stays `initial_summary_pending`; the `AiJobCriteria re-trigger (X3)` section.
- The gap = no broadcast / no UI signal during the `awaiting_job_criteria` and criteria-pending windows. Investigate what (if anything) currently signals progress to the UI during these windows, and what should.

### 5. The `AiJobCriteria` overwrite theory — investigate exhaustively (the fix is unconfirmed)
- **Current state (per Jessica):** the `Job → AiJobCriteria` association is ALREADY `has_many` now — changed AFTER the incident below, and UNTESTED for criteria creation. **Jessica does not know whether `has_many` is the solution** ("I don't know if that's the solution or not… I'm just proposing a theory… I don't know what the fuck happened"). Treat `has_many` as ONE hypothesis, not the answer.
- **Do this — not a read-only verdict:** trace exhaustively what happens to a FAILED `AiJobCriteria` under the current code, AND reproduce it — write and run tests, and/or exercise the flow (publish → `ExtractJobCriteriaJob`, plus a concurrent manual generate that also kicks off criteria) to OBSERVE whether a failed record is now preserved or overwritten. Actively hunt for OTHER causes/gaps — the real cause may not be the association at all.
- **Incident (under the OLD `has_one`):** she published a job → `ExtractJobCriteriaJob` triggered; minutes later the `AiJobCriteria` was still `pending`. She had also clicked a manual generate (resume summary), which itself kicks off the criteria job if no criteria exists. Under `has_one`, a failed-status save could have been overwritten by the re-trigger — unconfirmed.
- **Ripple audit:** the map (2026-06-22) shows SINGULAR usage — `ai_job_criteria&.status_succeeded?` in `check_criteria_and_score`, `resume_waiting_summaries` (`ai_job_criteria.rb:17`), readers of `job.ai_job_criteria`. Under `has_many`, `job.ai_job_criteria` is a collection. Reconcile every singular reference against LIVE code (were callers updated? which record do they pick?). The map may now be stale on cardinality — reconcile map vs live code first.

### 6. `AiJobCriteria` possibly stuck `pending` forever (investigate fully; don't build the fix tonight)
- Determine whether an `AiJobCriteria` can sit in `pending` with no actor advancing it (the incident in issue 5 never left `pending`). Investigate it fully and document, with evidence, whether it is real and under what conditions.
- Do NOT build a mitigation (e.g. a polling rake task) tonight — that needs more usage data. Investigate ≠ build. Related to issue 4 (no signal during pending).

### Beyond the above
Investigate any other gap the map surfaces; propose solutions; double-check each is a REAL gap (apply the "later-resolved ≠ gap" rule).

## Conventions to read (before drafting spec/plan)

- Global: `/Users/jessica/.claude/CLAUDE.md`
- Pipeline: `/Users/jessica/claude-hub/inflow-ats/CLAUDE.md`
- Source repo: `/Users/jessica/wrk/wrk-corp/inflow-ats/CLAUDE.md` + `cursor_rules/` (read `core_critical_rules.md` plus the area `_base.md` for each area touched — backend, and frontend if F1 is in scope). Do NOT read all 45 cursor_rules upfront.

## Process / sequence

1. **Explore (workflow).** Launch a workflow — many parallel agents — to investigate issues 1-6 and anything related, each proven against the map + live code (reproduce where reading is not enough). Produce a findings report: CURRENT / INTENDED / DELTA + evidence per issue, with `file:line`. Save it; do NOT wait for a reply (Jessica is asleep) — continue to the spec.
2. **Spec.** Draft the spec from the confirmed findings.
3. **Lifecycle.** Read `/Users/jessica/claude-hub/features/LIFECYCLE.md` and follow it through the end of **Phase 7**. **STOP before Phase 8** (do not start QA). The lifecycle auto-finds the inflow-ats prompt overrides at `~/claude-hub/inflow-ats/features/`.

The Method above (propose / trace side effects / audit vs map / adversarial plan review) maps onto the lifecycle's spec-review and plan-review phases — use the lifecycle phases rather than duplicating them.

## Workspace, branch, and git rules

- **You are launched from the `claude-hub` launcher, NOT from inside the source repo.** Do ALL code / git / test / rails console / migration work in the source repo at `/Users/jessica/wrk/wrk-corp/inflow-ats` — `cd` there, or use absolute paths and `git -C /Users/jessica/wrk/wrk-corp/inflow-ats ...`. The hub holds the map and your output artifacts; the code lives in the source repo.
- **Branch (already created and checked out):** all code work happens on **`ai-summary-creation-gaps`** in `/Users/jessica/wrk/wrk-corp/inflow-ats` (branched off `UI-polishes`). Confirm you are on it (`git -C /Users/jessica/wrk/wrk-corp/inflow-ats rev-parse --abbrev-ref HEAD`) before changing code. Do NOT switch to or commit on `master` / `UI-polishes` / `develop`.
- **Pre-loaded state on the branch:** the AI-summary/criteria spec changes are already applied (16 files under `spec/`, uncommitted), and `db/schema.rb` has been regenerated — the `ai_job_criteria.job_id` index is now NON-unique (the `has_many` change is migrated; migration `20260622204646 ChangeAiJobCriteriaJobIdIndexToNonUnique` is applied, DB is migrated). A backup of the specs is in `git stash@{0}`.
- **HARD RULE — never stage or commit `db/schema.rb`.** No agent stages or commits `db/schema.rb`, ever. It will show as modified all session; leave it modified.
- **Committing is optional this session.** Because `schema.rb` must stay unstaged and some Cypress tests may fail as a result, you may be unable to commit cleanly — that is acceptable. Leave the work uncommitted on the branch. Do NOT `git add db/schema.rb`, do NOT use `--no-verify`, do NOT rewrite tests to pass. If a commit cannot go through without breaking these rules, do not commit — the work stays on the branch.
- **Some Cypress tests may not pass this session — that is OK.** Do not chase green Cypress at the cost of the rules above.
- Write all non-code artifacts (findings report, spec, plan) to this hub subdir (`~/claude-hub/inflow-ats/features/ai-summary-creation-gaps-2026-06-23/`) — NOT into the source repo (do not create `_in-progress/` or any scratch files inside the source repo).
