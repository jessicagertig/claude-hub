# Plan review pass 1 — CLAUDE.md / safety compliance

Checked plan.md against global `~/.claude/CLAUDE.md` hard rules, `~/claude-hub/inflow-ats/CLAUDE.md`, and `cursor_rules/core_critical_rules.md`.

## Database safety (global CLAUDE.md hard rules)

- The only db command in the plan is `bundle exec rails db:migrate` (T3) — explicitly on the SAFE/ALLOWED list. No `db:drop`/`db:reset`/`db:setup`/`db:schema:load`, no `psql`, no `DATABASE_URL`, no `.env` edits anywhere in the plan. COMPLIANT.
- Migration data-loss risk: both migrations are additive `add_column ... :string`, nullable, no defaults — non-destructive; rollback would only drop empty new columns. No `db/data/` migrations involved (failure pattern 17 not applicable). COMPLIANT.

## SPEC §3 schema hunk-staging rule (HARD — Jessica 2026-07-24)

Carried into the plan in three places: §13 quotes the rule verbatim, T3 restates it at the task level, §4's `db/schema.rb` entry flags hunk-only commits, and risk 5 directs the impl review at the committed diff (pipeline failure pattern 15). COMPLIANT.

## Commit and branch rules

- Plan §13: never `--no-verify`; commits detached, never timed out under 20 minutes; work stays on `attribution-work-qa` (not master/develop); no new branches; merges/PRs are Jessica's. Matches pipeline CLAUDE.md and memory rules. COMPLIANT.
- Cypress files read-only (plan §4 not-touched list; T21). COMPLIANT.

## cursor_rules citations (verified against headings)

- Rule 5 (one params method) — cited at T10/T13 correctly (why `#update` is affected).
- Rule 7 (backend snake_case / frontend camelCase) — the wire-format design follows it.
- Rules 9/10 (never set undefined / never fabricate fallbacks) — T4k and plan §7 enforce; the T4 snippet complies.
- Rule 11 (no bang methods; spec exceptions) — plan notes "bang methods allowed in specs," matching the existing spec files' `User.create!` precedent.
- Rule 13 (strict comparisons; loose only vs undefined) — the T4 snippet uses `!== undefined`, the house form already used at utils.js:59-70.
- frontend/_base rule 1 (no `??`) — no nullish coalescing in any plan snippet.
- Rule 2a — the plan removes two `window.logger` calls only because their surrounding capture code is removed (SPEC §5.7 mandates it); not a compliance issue.

## Pipeline failure patterns spot-checked

- Pattern 15 (review committed code): plan risk 5 encodes it.
- Patterns 30/31 (Devise mapping + queue adapter in controller specs): existing spec files already have both; T19 explicitly preserves them.
- Pattern 10/23 (fix-agent scope): T9d and §12's "Nothing else may deviate" fence encode minimum scope.

## Findings

None. 0 BLOCKER, 0 HIGH, 0 MED, 0 LOW.
