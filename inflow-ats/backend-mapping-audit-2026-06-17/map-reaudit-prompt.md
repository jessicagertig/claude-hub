# Map Re-Audit — Parallel Agent Prompt Spec

## ⚙️ EXECUTION CONFIG — READ FULLY BEFORE SPAWNING ANY AGENT
**Do not spawn a single agent until this entire spec has been read end to end.**
- **MODEL: Opus, high/xhigh effort, for EVERY agent. NO HAIKU. Do NOT use the cheap `Explore` agentType.** Shallow Haiku exploration is the exact failure this audit exists to undo.
- Output: rich structured verdicts with long literal-code fields. NO compressed summaries.
- Each trigger/angle agent runs independently and in parallel. Synthesis is the only barrier.
- After synthesis, run the ADVERSARIAL REVIEW LOOP (Section 3) — repeat until TWO consecutive fully-clean passes before producing the final map.
- (Full execution notes repeated at the end — Section 4.)

---

**Goal:** Produce an accurate, complete, current-state map of the Textract + AI-summary + status-table + job-criteria backend flows — by verifying the existing map (`textract-ai-summary-map-6-6-2026-COPY.md`) line-by-line against the CURRENT codebase, integrating the net-new `AiJobApplicationSummaryStatus` table (absent from the map), and catching every other drift. This map is a DURABLE, REUSABLE BASE for any future investigation of these flows — it is NOT targeted at any single bug, question, or suspected defect. Audit neutrally: discover and document what the code does, do not set out to confirm any predetermined conclusion.

**Branch under audit:** `develop` (current main work tree at `/Users/jessica/wrk/wrk-corp/inflow-ats`; the tree is checked out to `UI-polishes`, which is byte-identical to `develop` — verified `git diff UI-polishes develop` empty, develop's only extra commits are merges of UI-polishes back in). Includes the bulk-summaries-generation fixes (`a01317b01 fix bulk ai summaries`, `31553f639 Fix ... all bulk actions when filtered`).

## INPUTS & PATHS (absolute — agents run with cwd = the repo worktree, so bare filenames will NOT resolve)
- **Repo worktree (code under audit, = agent cwd):** `/Users/jessica/wrk/wrk-corp/inflow-ats/`
- **Old map, READ-ONLY reference/template:** `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/textract-ai-summary-map-6-6-2026-COPY.md`
- **New map, synthesis OUTPUT (create):** `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/backend-flow-map-2026-06-17.md`
- **Per-agent verdicts written to:** `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/reviews/<angle>-pass-<N>.md` (e.g. `T2-pass-1.md`, `X1-pass-2.md`)

---

## 0. SHARED MANDATE — prepended to EVERY agent prompt

> You are auditing one slice of a large, interconnected AI pipeline (Textract OCR + AI applicant summary generation + a denormalized status table + job-criteria extraction). Jessica built every inch of this; the existing map is OUT OF DATE and must not be trusted as ground truth — it is a scope reference only. Verify everything against the current code.
>
> **Investigation discipline (non-negotiable):** For every identifier you encounter — method, class, constant, association, enum, callback, job, service, interactor, scope, column, broadcast, flipper, route — locate and READ its definition. If not in the current file, search the codebase. Continue until every identifier you encountered on your path has had its definition read. Stop tracing only at a framework/gem boundary (read that definition once, don't recurse into the gem's internals). Print the explicit chain of files you followed (e.g. `A.rb:12 → B.rb:40 → C.rb:9`).
>
> **No inference from names. No summarizing.** Every claim you make must be backed by the literal line of code (file:line + the actual source line quoted). Do not paraphrase behavior. Do not stop at the first plausible answer. "Exhaustive" means spend whatever tokens are needed to read every branch.
>
> **Read, don't grep-and-infer.** Grep/Glob are for LOCATING candidates only. Before you state what any line does, OPEN the file and READ it (and read the definitions it calls, per the discipline above). Never characterize a write site, a guard, or a callback from a grep hit alone — a `.update` line means nothing until you've read what fires around it (callbacks, guards, transaction, the enum it writes).
>
> **The anchoring test:** if a statement in your output is not anchored on a file you actually opened and an identifier you actually traced, you have not done the work — delete it or go read the code. This is not the place to describe what you *would* check; do the check.
>
> **Trace each path to a TERMINAL state, not the entry point.** Follow your trigger all the way to where a record reaches a resting status (succeeded / failed / current / stuck-with-no-further-actor) — naming every intermediate transition and every actor (job, callback, re-trigger) that advances it. Flag any path that can come to rest WITHOUT a clearing/advancing actor (a dead end). Distinguish behavior that is NEW vs reused-from-before.
>
> **For your assigned slice, you must trace the full lifecycle of FOUR records and report every read and every write to each, with file:line:**
> 1. `TextractResult` — `textract_job_status` enum {not_started, in_progress, succeeded, failed}, `textract_job_result_text`.
> 2. `AiJobApplicationSummary` — `status` enum {pending, textract_processing, extracting, summarizing, awaiting_job_criteria, scoring, integrating, succeeded, retrying, failed}, `stale` boolean.
> 3. `AiJobApplicationSummaryStatus` — `status` enum {none, initial_summary_pending, current, regenerating} and its denormalized columns (`ai_job_application_summary_id`, `score_percentage`, `headline`, `integrated_role_analysis`). **This table is NOT in the existing map at all.** Its purpose: surface AI-summary display data on the infinite-loaded job-applications list cheaply (the full summary record is too heavy to load there). Because it is denormalized, it can fall OUT OF SYNC with the real summary — flag every window where the status row could disagree with the latest non-stale summary.
> 4. `AiJobCriteria` — `status` enum {pending, in_progress, succeeded, failed, retrying}, and its `resume_waiting_summaries` re-trigger.
>
> **Branch logic to capture explicitly on every path:** when a generation path runs and the job_application has NO usable Textract result, the summary goes to `textract_processing` and waits; when Textract IS ready, it moves forward into the AI pipeline. State which branch your path takes and where (file:line).
>
> **Output contract:** Return a structured per-claim verdict (see schema) AND write the same content to your reviews file (`reviews/<angle>-pass-<N>.md`). For every behavior on your slice: (a) what the current code does, file:line + literal line; (b) what the existing map says about it (quote the map line/section, or "ABSENT from map"); (c) verdict: CONFIRMED / CHANGED / NEW / REMOVED / MAP-WRONG; (d) the exact text to write into the updated map for this point. Do not editorialize. Identifiers exact. End with the explicit list of every record-write site (file:line) you found on your slice — this feeds the coverage cross-check.

---

## 1. AGENT ROSTER — one agent per trigger/path

Each agent owns ONE trigger and traces EVERY path out of it to a terminal state, applying the shared mandate. Agents run in parallel; none trusts another's output.

### Textract-trigger agents (verify each still exists; discover any new)
- **T1 — New job application created:** `JobApplication after_commit :enqueue_new_job_application, on: :create` → `SubmitResumeToTextractJob`. All creation sources. Flipper `TEXTRACT_RESUME_PROCESSING`.
- **T2 — Manual resume upload / replacement (internal):** controller update action resume-param path → `SubmitResumeToTextractJob`. (This is the resume-replacement path — trace stale-marking and what it does to the status row.)
- **T3 — Clone job application to another job.**
- **T4 — Customer API apply.**
- **T5 — Customer API import.**
- **T6 — CSV bulk import** (external_resume_url, no resume at creation).
- **T7 — External resume URL lazy attachment** (`AttachExternalResumeUrlJob`) — verify whether Textract is or isn't triggered now.
- **T8 — Bulk AI summary backfill** (`QueueBulkAiSummaryJobs` resume-but-no-textract).
- **T9 — Manual generate when no TextractResult** (`ValidateAiSummaryGeneration` kicks off Textract).

### AI-summary-trigger agents (verify each; discover any new)
- **S-A — Manual single generate:** controller create → `ValidateAiSummaryGeneration` → `CreateAiSummaryGeneration` → job → `Orchestrate`. Trace both sub-branches: Textract ready (`pending`, job enqueued now) vs Textract pending (`textract_processing`, no job, waits for callback).
- **S-B — Bulk generate:** `QueueBulkAiSummaryJobs` → `BulkGenerateAiSummariesJob` → per-candidate `generate_ai_summary_with_credit_flow` (bypasses `CreateAiSummaryGeneration`).
- **S-C — Auto-generate via TextractResult callback:** `TextractResult after_commit :queue_ai_summary_job` (no waiting summary + auto-generate setting).
- **S-D — Resume-replacement re-generation:** the path when a prior summary already exists for the job_application and a new resume/Textract result arrives. Trace exactly which `AiJobApplicationSummary` record each step operates on (which one `Orchestrate` selects, by what ordering/filter), every status it passes through, and where the path comes to rest. Document the actual behavior — do not presume an outcome.
- **S-E — Textract-processing handoff:** callback finds an existing `textract_processing` summary and runs it.

### Cross-cutting dedicated agents
- **X0 — Writer census (runs first conceptually; the authoritative coverage baseline):** Grep the ENTIRE codebase (app/, lib/, jobs, services, interactors, models, controllers, channels, rake tasks) for every site that WRITES to any of the four records' status/key columns: `TextractResult.textract_job_status` / `textract_job_result_text`; `AiJobApplicationSummary.status` / `stale`; `AiJobApplicationSummaryStatus.status` and its denormalized columns; `AiJobCriteria.status`. Catch every form: `.update`, `.update_columns`, `.update_column`, `.update_all`, `.save`, direct `x.status =`, enum bang methods (`status_xxx!`), `build`/`create` with a status, raw SQL. Produce the authoritative numbered list of write sites (file:line + literal line + which column + update-vs-update_columns). This list is the coverage baseline: synthesis must confirm EVERY entry is owned by at least one trigger/angle agent. Flag any writer no trigger agent claims as an ORPHAN (an undiscovered path).
- **X1 — `AiJobApplicationSummaryStatus` table (whole-codebase):** find EVERY read and EVERY write of this table and its columns across app/, lib/, serializers, controllers, jobs, channels, and the frontend consumers (what the infinite-loaded list reads). Build the COMPLETE state-transition table for its `status` field: every value (none / initial_summary_pending / current / regenerating), every transition, the exact writer of each (file:line + literal line), the precise precondition under which each writer fires, and which trigger path(s) reach it. For each value, note whether it is a resting state and what actor (if any) advances out of it. Because this table is denormalized, also map every window where the row can disagree with the job_application's latest non-stale `AiJobApplicationSummary` (desync surface). Document actual behavior; do not judge any transition as right or wrong.
- **X2 — Setter/clearer focus:** trace `find_or_create_ai_job_application_summary_status` and `AiJobApplicationSummary#update_summary_status_record` (and any other writer) in full; enumerate every caller and the exact precondition under which each fires; confirm whether `.update` vs `update_columns` is used at each write (callback-firing implications).
- **X3 — `AiJobCriteria` re-trigger:** `resume_waiting_summaries` — when it fires, its exact precondition, what it re-enqueues, and what becomes of an `awaiting_job_criteria` summary under each criteria outcome (succeeded / failed / retrying / pending / in_progress / never-reached). Document each branch; do not presume a failure.
- **F1 — Frontend status consumers (the reason the status table exists):** Trace what the infinite-loaded job-applications list renders for AI summary state — the serializer(s) that expose `AiJobApplicationSummaryStatus` fields, the React Query hooks that fetch them, the components that read `status` (none/initial_summary_pending/current/regenerating) and the denormalized columns, and the websocket handler for `ai_summary_status_change` (what it refetches/mutates). Identify any optimistic-UI or cache path that can make the FE DISPLAY any status value while the DB row says otherwise — i.e. display-only desync vs true desync. file:line for every reader.

---

## 2. SYNTHESIS AGENT — runs after all of the above

> You receive every per-slice audit verdict. Produce:
> 1. **The corrected, current-state map — written to a NEW file `backend-flow-map-2026-06-17.md` in this audit directory.** `textract-ai-summary-map-6-6-2026-COPY.md` is a READ-ONLY reference (the old, out-of-date map) — use it only as the structural template and to diff against; NEVER edit or overwrite it. The new map mirrors its structure, updated to reflect verified current code, with a NEW dedicated section for the `AiJobApplicationSummaryStatus` table (data model, every transition, every reader including the frontend list, every desync window).
> 2. **A divergence changelog** — every CHANGED / NEW / REMOVED / MAP-WRONG verdict, grouped by trigger, each with file:line.
> 3. **Complete state-transition tables — one per record** (`TextractResult`, `AiJobApplicationSummary`, `AiJobApplicationSummaryStatus`, `AiJobCriteria`). For each: every status value, every transition with its writer (file:line + literal line) and exact precondition, and which trigger path(s) reach it. Mark every RESTING state and the actor (if any) that advances out of it. Flag any resting state reachable with NO actor that will advance it — a dead end — for ANY record/status, named neutrally (do not single out any one status). This is descriptive cartography, not a verdict on correctness.
> 4. **Coverage cross-check** — take X0's writer census and confirm EVERY write site is owned by at least one trigger/angle agent's trace. List any ORPHAN write site (covered by no agent) as a discovered gap requiring a new angle. The audit is not complete while orphans remain.
> Reconcile conflicts between agents by re-citing the actual code; never average them. Identifiers exact, no editorializing. Do not target, hunt, or pre-judge any specific bug — produce the map.

---

## 3. ADVERSARIAL REVIEW LOOP — runs after first synthesis, repeats until 2 clean passes

After the synthesis agent produces a candidate map, re-run the SAME original angles (every T#, S-#, and X# agent) in adversarial mode against that candidate. Goal: try to BREAK it.

> **Adversarial review prompt (per original angle):** You previously audited slice [X]. A synthesized current-state map now exists. Your job is to REFUTE it for your slice. Re-read the current code from scratch (do not trust the prior pass). For every statement the candidate map makes about your slice, attempt to prove it wrong against literal code (file:line). Report each as: AGREE (cite code) or DISPUTE (cite the contradicting code + the correction). Default to skepticism — if you cannot fully verify a claim against code, mark it DISPUTE, not AGREE. Find anything the map OMITS for your slice. Apply the full shared mandate (Section 0): every identifier traced, every claim quoted, no summarizing.

**Loop control:**
- A pass is **CLEAN** only if EVERY angle returns zero DISPUTE and zero omission for its slice.
- If any angle DISPUTES or finds an omission: synthesis incorporates the correction, produces a new candidate map, and the loop runs AGAIN.
- Continue until **TWO CONSECUTIVE fully-clean passes** (every angle AGREE on both). One clean pass is not enough — the second confirms the first wasn't luck.
- Log each round: which angles disputed what (file:line), so the convergence is auditable. No silent dropping of a dispute. Each round's per-angle output goes to `reviews/<angle>-pass-<N>.md`.
- **Round cap:** if not converged after 6 rounds, STOP and surface the still-unresolved disputes (with both sides' file:line) for human decision rather than looping indefinitely. A persistent dispute usually means the code itself is genuinely ambiguous/buggy at that spot — that is itself a finding.

---

## 4. EXECUTION NOTES (repeat of top config — for the Workflow script, not the agents)
- **Model: Opus, high/xhigh effort for every agent. NO HAIKU. NOT the cheap `Explore` agentType.**
- Output: rich structured verdicts, NOT compressed summaries. Schema allows long literal-code fields.
- Read this entire spec before spawning any agent.
- Each trigger/angle agent runs independently and in parallel; synthesis is the only barrier.
- Adversarial review loop (Section 3) repeats until TWO consecutive clean passes.
- Synthesis writes the final updated map to a NEW file `backend-flow-map-2026-06-17.md` in the audit directory. The COPY (`textract-ai-summary-map-6-6-2026-COPY.md`) is read-only — never edited or overwritten by any agent.
