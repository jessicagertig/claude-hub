# Round 1 — Angle 8: cursor_rules compliance of the SPEC's proposed code + Always-on checks

Rules files read this round: `core_critical_rules.md` (full), `backend/serializers.md` (full rule list + §7), `frontend/_base.md` §1. The remaining area files are enforced at Phase 6 via the fan-out map; this angle checks the SPEC'S PROPOSED CODE against the rules the spec itself cites.

## Spec-code compliance (verified against core_critical_rules.md)

- **Rule 1 (no begin blocks):** controller code (SPEC 5.2) has none ✓.
- **Rule 5 (one params method max):** controller has ZERO params methods — no body params accepted; compliant ✓.
- **Rule 7 (casing + Ruby-enum exception, verified at core_critical_rules.md:147-149):** serializer emits snake_case keys (api.ts transforms); enum VALUES (`status`, `tier`) stay snake_case in TS types; WS payload keys camelCase-in-Ruby per the socket-path convention ✓.
- **Rule 8 (bare guards):** every spec'd guard is a bare `return unless`/`return if` (job.rb changes, funnel guard, broadcast helper `return unless`) ✓. Controller early returns render a response first — sanctioned form.
- **Rule 10 (no fabricated fallbacks):** serializer uses safe-nav returning nil; hook has no `|| 0`-style fallbacks; 8.3 explicitly prohibits `criteria || []` ✓.
- **Rule 11 (no bangs):** none in spec'd app code; `context.fail!` is the Interactor API, not an AR bang — matches every existing validator ✓. Bangs in RSpec plans are sanctioned (rule 11 exception).
- **Rule 12 (check save returns):** `return unless new_ai_job_criteria.save` (4.1) ✓; `update_columns` writes follow the sibling-write pattern and sit outside transactions (pipeline rule 25, verified for each_iteration) ✓.
- **Variable naming for records:** `ai_job_criteria`, `new_ai_job_criteria`, `requesting_organization_user`, `job_application_bulk_job_status` — full-model-name snake_case throughout the spec'd code; no `row`/`record`/`latest` ✓.
- **serializers.md §1/§2/§3/§7:** jsonb pass-through; predicate attribute without `?` delegating to the model; computed methods delegate to Job model methods ✓.
- **frontend/_base.md §1:** no `??` in any spec'd TS ✓. Double quotes throughout spec'd TS ✓ (single quotes in Ruby ✓).
- **File naming:** `ai_job_criteria_controller.rb`, `job_ai_job_criteria_serializer.rb`, `useAiJobCriteria.ts`, `JobCriteriaViewModal.tsx`, `RegenerateJobCriteriaConfirmModal.tsx` — all per conventions ✓.
- **Never-edit files:** ModalContext/ToastContext/api.ts absent from section 13 ✓.

## Always-on checks (folded here per round discipline)

**Source accuracy:** every citation leaned on this round was re-verified (see per-angle files). Three stale citations found and fixed (Angle 5 F3). Route line numbers 189/224/265/314 exact. DECISIONS.md honored everywhere outside the 7 sanctioned flags — full sweep done (gating code verbatim+kwarg; blank-description error; WS toast; review guard traced; empty-state/sidebar copy verbatim; loading states; regenerate-any-state; all Decided-OUT items absent; copy rules; visual specs; test plan present). No unsanctioned deviation found.

**Test coverage (pipeline rule 3):** SPEC 12 present — 3 new spec files (verified absent today), 8 modified (verified all exist on disk), frontend none with documented reasoning (verified: only Button.test.tsx exists). Load-bearing cases all named: six serializer states, three-message truth table, no-pending-guard documentation test, claim-row `:failed` test, behavioral broadcast tests (rule 26 phrasing — outcomes, not reflection).

**Backward compatibility:**
- `ExtractJobCriteriaJob`: flag 4 resolved to optional positional — already-enqueued `[id]` payloads and all four enqueue sites keep working with zero transition machinery (Angle 3).
- `extract_job_criteria_immediately` kwarg default nil — sole existing caller `extract_job_criteria_if_needed` (job.rb:742) unchanged; `auto_extract_job_criteria`/`extract_job_criteria` untouched (asymmetry preserved, trace note 4 adjudicated in Angle 3).
- `QueueBulkAiSummaryJobs` optional `job` input, safe-nav — job-less callers pass; spec plan asserts it.
- Both validators gain one fail — all existing callers traced (Angle 1); textract manual-waiting branch destroys the waiting summary and broadcasts AI_SUMMARY_FAILED with the new message via the EXISTING mechanism (textract_result.rb:134-137) — no caller treats a new message as unexpected.
- `aiSummaryWebsocketPayloads.ts`: additive only. `JobSetupAiSettings.tsx`: existing form flow preserved; sidebar layout shift flagged for QA.

**Full-stack analog completeness:** every layer of the section-2 analog table has a specced counterpart — confirm modal owning mutation (8.5) → hook (8.1) → route (5.1) → controller (5.2) → validator/guard (6) → async job (7) → broadcast helper (7) → channel (GlobalChannel) → WS handler case (8.6) → payload type (8.7) → query invalidation (8.1 onSuccess + 8.6 handler). No missing layer.

**Analog structural matching (rule 14):** parameter interface deviation = flag 4, adjudicated with evidence (Angle 3); retry/exhaustion broadcast added to the EXISTING exhaustion block, arg-reading style matches the chosen signature form; no new callbacks specced on AiJobCriteria/Job (resume_waiting_summaries untouched); error-handling dual-rescue shape mirrors the analog including (after this round's F2 amendment) the row-presence guards; serializer/status-pointer deviation spec-adjudicated with verified rationale (Angle 4).

## Findings

No issues found (violations); compliance confirmed for all spec'd code.

## Amendments Applied

None (this angle).
