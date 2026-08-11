# CLAUDE.md / cursor_rules Compliance — Pass 1

Read: global `~/.claude/CLAUDE.md`, hub `CLAUDE.md`, pipeline `inflow-ats/CLAUDE.md`, `cursor_rules/core_critical_rules.md`.

## Database safety (global hard rules)
- No `DROP DATABASE`, `db:reset`/`db:setup`/`db:schema:load`, no `psql`, no `DATABASE_URL`, no `.env` edits. Plan introduces NONE. No migrations. Specs create data via app models inside RSpec (allowed). PASS.
- No `update_columns` introduced (rule 25); B4.2 explicitly forbids porting the bulk interactor's `update_columns` staleness block. PASS.

## Breaking-existing-functionality
- `GenerateParams.rescoreRequested` becomes required — only consumers `PlatoTab.tsx` (updated) + `AiSummaryState.tsx` (deleted); no third survivor (grep-confirmed). No compile break given F3+F4+F5 atomicity. PASS.
- Mailer method signatures unchanged (`user_id` retained); callers in `bulk_generate_ai_summaries_job.rb` unaffected. PASS.
- `BulkGenerateAiSummariesConfirmModal` props unchanged; sole caller `JobStageMenu.tsx` unaffected. PASS.

## cursor_rules/core_critical_rules.md
- Rule 1 (no begin blocks): B6 adds a params method + one assignment, no begin block. PASS.
- Rule 5 (one params method): B6.1 adds exactly one (`ai_job_application_summary_params`). PASS.
- Rule 8 (bare guard returns): mailer `return unless recipients.any?` is bare. PASS.
- Rule 9 (`undefined` never set): frontend passes literals `true`/`false`, no `undefined`. PASS.
- Rule 10 / known-failure #13 (no fabricated fallback): required boolean, always sent; no `|| 0`-style default. PASS.
- Rule 11 (no bang methods outside spec): bang methods appear only in the new/edited specs (allowed). PASS.
- Rule 13 (styled components, no className): new styled components per element; no new className styling. PASS.
- Rule 26 / known-failure #26 (no ghost tests): T1.4/T1.5, T2.5, T3.4 assertions all falsifiable by reverting the feature line. PASS.
- Known-failure #11 (`loading`+`disabled` pairing): Regenerate Button keeps `loading={buttonLoading} disabled={buttonLoading}`; new submit Button keeps `loading={isLoading}` with `disabled` including `isLoading`. PASS.
- Known-failure #23 (scoped deletion): only `AiSummaryState.tsx` deleted. PASS.
- Known-failure #7 (stubs must not mask param mismatch): T3 stubs pass `rescore_requested` in the real shape. PASS.

## Scope & ordering
- Every task traces to a SPEC section (A1→1.1-1.4, A2→1.5, B1→1.6, T1→1.7, B4→2.1, B6→2.2, F3→2.3, F4→2.4/2.5, F5→2.6, T2/T3→2.8). No "while we're here" additions. PASS.
- HARD atomic unit F3+F4+F5 (TS compile) and CORRECTNESS same-merge A2+B1 stated. PASS.

## Findings (cross-cutting)
- F1 [LOW] plan line 66: "the controller param (F6)" — no Task F6 exists; the controller task is Task B6. Internal-label error. **Amended → "(B6)".**
- F2 [LOW] plan F4.4: failed-state `onClick={handleGenerate}` cited at "line 202"; actual line 203 (three identical bare callsites at 192/203/233, all handled; state descriptor unambiguous). **Amended → "line 203".**
- F3 [LOW] plan scope counts ("9 modified", `Estimated scope` "9 files") don't match the 8-file inflow-ats enumeration (and exclude the 2 polymer-mail templates handled in B1.6). Prose-only; every file to touch is explicitly named in the task steps, so no action is affected. Not amended.

## Verdict: PASS (0 BLOCKER, 0 HIGH; 3 LOW, 2 corrected inline)
