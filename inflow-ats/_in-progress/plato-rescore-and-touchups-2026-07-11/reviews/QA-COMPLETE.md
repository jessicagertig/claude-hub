# QA Verification — COMPLETE

**Feature:** Plato re-score — per-stage bulk checkbox + modal copy restructure + all-stages mailer recipients (Item 1); single-send Regenerate re-score (Item 2)
**Branch:** `job-criteria-settings-qa` @ `cca9222a5` (worktree /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings)
**Commits under QA:** `f9ec4a80d` (feature) + `970b0f4b2` (QA fix 1) + `cca9222a5` (QA fix 2) — the two QA fixes are spec-file-only; feature code is untouched since Phase 6 approval.
**Second repo:** polymer-mail — 2 all-stages `.mjml` greeting deletions verified in Layer 1 (working tree; commit deliberately waits for the Mailgun paste per repo convention)
**Date:** 2026-07-12

## Final verdict: APPROVED

## Layer plan (owner-approved overrides — recorded, no silent caps)
- **Layer 1 (diff-to-spec):** RUN, full intensity.
- **Layer 2 (code correctness):** SKIPPED — owner-approved; overlaps Phase 6's two clean fresh-agent rounds; analog content pinned verbatim in SPEC.md and checked by Layer 1.
- **Layer 3 (script runner):** SKIPPED — owner-approved; backend surface is three small changes fully covered by the new RSpec files (run in Layer 4) and exercised end-to-end in Layer 5.
- **Layer 4 (regression suites):** RUN (owner-scoped six spec files).
- **Layer 5 (Playwright MCP):** RUN, full — 2 rounds x 15 agents including REAL end-to-end AI runs.

## Runs and fix cycles
| Run | Layer reached | Outcome |
|---|---|---|
| qa-run-1 | Layer 1 round 1 (10 agents) | 1 HIGH: l1-7-001 — new controller spec's rejection test posted an empty `ai_job_application_summary` hash, so the outer `require` raised before `.require(:rescore_requested)` was exercised (rule-26 tautology). Fixed: commit `970b0f4b2` (+1/−1, payload `{ irrelevant: 'x' }`). Restart. |
| qa-run-2 | Layer 1 round 1 (6 agents) | 1 HIGH: l1-3-001 — interactor spec false-path example omitted the bulk analog's count-invariance assertion (SPEC 2.8 pins "the same assertion pairs"). Fixed: commit `cca9222a5` (+5/−3, one example). Restart. |
| qa-run-3 | ALL layers | CLEAN — converged. Details below. |

Both fixes went through the Phase 5 fix-agent loop (minimal scope verified by the next run's Layer 1), were committed with full pre-commit Cypress hook runs (56/56 green each), and re-reviewed from scratch.

## qa-run-3 layer-by-layer
- **Layer 1:** round 1 — 5 agents, 0 findings; round 2 — 5 fresh agents, 0 findings. CONVERGED (two consecutive clean rounds). Both QA fix commits verified minimal, effective, falsifiable; forward+reverse hunk-to-SPEC traces clean; all owner-sanctioned divergences respected.
- **Layer 4:** 26 examples, 0 failures across the six owner-scoped files (`create_ai_summary_generation_spec`, `ai_job_application_summaries_controller_spec`, `bulk_all_stages_ai_summary_result_mailer_spec`, `queue_bulk_ai_summary_jobs_spec`, `create_bulk_ai_summary_generation_spec`, `bulk_ai_job_application_summaries_controller_spec`); identical result on a confirmation re-run. PASS.
- **Layer 5:** round 1 — 15 sequential agents, 0 HIGH after adjudication; round 2 — 15 fresh agents, 0 HIGH, prior adjudication independently validated. CONVERGED. No blocking-fix or batch-fix files. Core targets, all verified at runtime with byte-level copy assertions:
  - Per-stage modal: all 5 SPEC 1.2 states in precedence order, incl. disabled checkbox+submit in no-selection, numeric-0 zero-processable copy, normal + shortfall credit variants, checked full-selection count (3→5 switch verified), partial-selection counts.
  - Overestimate block + tooltip (SPEC 1.3): exact strings, correct render condition — present only on unloaded Select-All + unchecked; disappears when checked AND when all 55 rows are client-loaded.
  - All-stages modal (SPEC 1.5): zero-state, checked sentence with NO leading "The", live shortfall recomputation at balances 20/16/15, Statement sentences (per-stage vs all-stages wording difference confirmed unswapped).
  - Regenerate gating (SPEC 2.5): button renders for every non-stale current review (3 organic + 4 seeded across both jobs); noResume empty state intact; confirm modal shows live balance.
  - REAL single-send re-score, twice (SPEC Item 2): POST `rescore_requested: true` → 200 → new succeeded summary row replaces display (~56 s inline), prior review visible during run (SPEC 2.7 status path), Regenerate persists, 1 credit each (20→19, 16→15).
  - REAL per-stage bulk re-score (SPEC Item 1): 3 selected + checked → `queued_count: 3, skipped_count: 0`, all 3 re-scored with fresh reviews, 3 credits (19→16); payload carried job_id + hiring_stage_id + selection sets (bulk contract).
  - Skip path, twice at zero cost: unchecked run over resume-less candidates → `queued_count: 0, skipped_count: 3`, toast "3 skipped (no resume, already processing, or not enough credits)", balance unchanged — Statement skip-reasons copy is truthful.
  - Console/network/websocket sweeps clean beyond the known pre-existing noise set.

## Totals
- **Runs:** 3 (two Layer-1 fix cycles, then a fully clean run).
- **Sub-agents dispatched:** 60 (Layer 1: 10+6+10; fix agents: 2; Layer 4: 1; seed/fixture planner: 1; Layer 5: 30).
- **Findings:** 2 HIGH total (both Layer 1 test-quality defects, both fixed + re-reviewed); 0 HIGH in any runtime layer. MEDs/LOWs: see `QA-MED-FINDINGS.md`.
- **Real AI spend:** 5 successful generations (2 single-send + 3 bulk), 5 AI credits from the fixture balance of 20.

## Environment notes (not feature defects)
- Test env runs ActiveJob inline; generation POSTs block for the whole AI pipeline (~1-5 min) — expected in RAILS_ENV=test only (production uses Sidekiq).
- Mailgun sends are suppressed in test (`send_message ... unless Rails.env.test?`): mailer recipient behavior is covered by the green mailer spec, not the browser layer.
- One fixture-script repair mid-setup (qa-harness fixture, not app code): the script passed an in-memory `job_application` whose `latest_ai_job_application_summary` has_one was cached nil; fixed by loading fresh before `FindOrCreateAiJobApplicationSummaryStatus.call`. App flows are unaffected — both real re-score paths exercised the same interactor correctly at runtime.
- Jessica's in-progress worktree edits (`.claude/CLAUDE.md`, `cursor_rules/core_critical_rules.md`) left untouched and uncommitted, as instructed. No Layer 5 flow was affected by the deferred styling work.

## For Jessica
- `QA-MED-FINDINGS.md` — 2 MEDs (score-0 fit chip pre-existing; deterministic re-score headline observation) + merge-time notes + LOWs.
- Manual action items (loose-ends.md): Mailgun paste of the two all-stages templates (then commit polymer-mail); your own deferred job-card / job-criteria styling changes.
