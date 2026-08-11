# CLAUDE.md / safety compliance — Pass 1

Inputs read: `~/.claude/CLAUDE.md` (global), `~/claude-hub/CLAUDE.md` (hub), `~/claude-hub/inflow-ats/CLAUDE.md` (pipeline), `<REPO>/cursor_rules/core_critical_rules.md`.

## Database safety (global hard rules)

- No `db:drop`/`db:reset`/`db:setup`/`db:schema:load`/`db:test:prepare` anywhere in the plan ✓ — the only DB-adjacent commands are `bundle exec rspec` runs (E.1.6, E.2.7, E.3.3, E.4.8, E.5.5, F.4.3)
- No `psql`, no MCP DB tools, no `DATABASE_URL`, no `.env` edits ✓
- **No migrations at all** (SPEC §3 "None", plan C inventory has no migration files) — zero data-loss risk, rule 17/19 (rollback/data-migration hazards) not in play ✓

## Branch / commit discipline

- Branch `job-criteria-settings` (not master/main/develop) ✓; §J "No branch operations" ✓; never-delete-branches not implicated ✓
- Pre-commit tests non-negotiable: §J "never `--no-verify`, never weaken a test to pass; commit via `nvm use && git commit ...` outside the sandbox" ✓ matches pipeline hard rule verbatim
- Commit messages end with the Claude Code attribution footer ✓ (global rule requires the Co-Authored-By line; the extra 🤖 line is harmless)
- Rule 15 (review committed code): F.4.4 requires `git status` clean before review ✓

## Risk of breaking existing functionality

- Backward-compat invariants enumerated (§G): old positional `[id]` Sidekiq payloads still perform (flag 4's whole point); `_immediately` callable with no args; `QueueBulkAiSummaryJobs` callable without `job:`; existing positional job-spec examples pass unmodified; existing WS interfaces untouched ✓ — each verified feasible against source
- Existing `JobSetupAiSettings` save flow byte-preserved (F.2.2); sidebar layout change flagged for visual verification (F.2.2.3, R-4) ✓
- The one shared-infrastructure behavior change (bulk claim-row fix) is flag 6, APPROVED as reviewed scope, and the plan keeps it minimal ✓ (after the Pass-1 F1 amendment removing the double-call ambiguity)

## Authorization / policy changes

- No new policy methods; existing `JobPolicy#show?` and `#update_ai_settings?` reused; both verified to read only `user` (safe for a Job record); org scoping via `current_organization.jobs` ✓
- Flipper `AI_APPLICANT_SUMMARY` on POST only; GET ungated per the `ai_credits` analog — spec-adjudicated, carried in the plan with the rationale ✓

## Pipeline known-failure-pattern rules (1, 3, 10-16, 20-26)

- Rule 3 (test plan): §H + per-task specs; frontend "none" documented ✓
- Rules 10/20/23 (fix-agent discipline): §G binding checklist ✓
- Rule 11 (behavioral props): F.3.2.5 both `loading` and `disabled` ✓
- Rule 12 (separate styled variants): F.2.1.7 ✓
- Rule 13 (no fabricated fallbacks): F preamble + F.4.1 ✓
- Rule 14 (structural analog matching): §B P5/P6; sole deviation flag-4-adjudicated ✓
- Rule 16 n/a (no companion-record creation added — `find_or_create_ai_job_application_summary_status` flow untouched) ✓
- Rule 21 (stay in lifecycle loop): plan defers fixes to review rounds ✓
- Rule 22 (frozen props): both modals handled per rule; mutation inside confirm modal ✓
- Rule 25 (`update_columns` not in transactions): all three sites verified outside transactions ✓
- Rule 26 (falsifiable tests): broadcast/enqueue assertions behavioral ✓

## Violations found

1. **[MED] E.2.5 `ai_job_criteria.reload` vs `cursor_rules/backend/_base.md` §8 ("No `reload` in Application Code"; "If you believe `reload` is genuinely necessary, ask the user").** The plan ships the SPEC-verbatim helper (reload included) and documents the conflict as R-1 with the rule-compliant alternative (`AiJobCriteria.find_by(id: ...)` re-query, the analog's approach) and an explicit human-gate hand-off. Because SPEC §7 specifies the reload, REVIEW-ANGLES Angle 3 requires verifying it, and R-1 forbids preemptive deviation, this is a documented gate-bound tension rather than a silent violation. It WILL be flagged by the Phase 6.5 conventions pass exactly as R-1 predicts; Jessica's ruling closes it. No plan amendment (amending would contradict the spec).

No other CLAUDE.md or cursor_rules violations found in any plan step.
