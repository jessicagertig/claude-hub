# CLAUDE.md / Safety Compliance — Pass 1

Sources read: `~/.claude/CLAUDE.md` (global), `~/claude-hub/CLAUDE.md` (hub), `~/claude-hub/inflow-ats/CLAUDE.md` (pipeline), `<REPO>/cursor_rules/core_critical_rules.md`.

## Database safety (global hard rules)

- B2.2/V1 use ONLY `bundle exec rails db:migrate` (dev) and `RAILS_ENV=test bundle exec rails db:migrate` (test) — both on the explicitly-allowed list. The plan itself prohibits `db:test:prepare`/`db:schema:load`/`db:setup`/`db:reset` in B2.2 and Risk 5. ✓
- No `psql`, no direct SQL, no `DATABASE_URL`, no `.env` edits anywhere in the plan. ✓
- No `db/data/` migration (D6 no-backfill) — nothing to trip the rollback/data-migration hazard (pipeline rule 17). ✓
- Migrations are purely additive (`add_column`, nullable, no default) — zero data-loss risk on existing rows; rollback would merely drop empty columns. ✓

## Branch / commit discipline

- Branch `attribution-work` (not master/main/develop) — verified live. ✓
- Implementation-order step 5: `nvm use && git commit …` outside sandbox, pre-commit runs Cypress + lint-staged, NEVER `--no-verify`; Risk 7 forbids bypassing the hook on unrelated failures. ✓
- Pipeline rule 15 (review committed code) is called out. ✓

## Breaking-existing-functionality review

- `from_omniauth` keyword conversion is the one breaking interface change; mitigations (B6.3 census re-run + post-conversion re-grep, T3.5/T4.3 interface pins) are in place and D9-mandated. ✓
- `magic_create` response shapes, failure redirect, existing mount effect, `useMagicLink`/`useRegister` wrappers, serializers, policies, jobs, contexts, `api.ts`, Cypress — all on the Do-NOT-touch list with V8 zero-diff verification. ✓
- Server params tolerance: new params optional in both directions (old clients unaffected; unpermitted extras ignored — verified `action_on_unpermitted_parameters` is the Rails default `:log` in test/dev). ✓

## Authorization / policy

- No new endpoints; unauthenticated signup paths unchanged by design; `organizations#create` keeps `authorize @organization`; `confirmations#show` stays token-authenticated. No policy file changes. ✓ (Matches spec §6.)

## cursor_rules compliance

See `conventions-compliance.md` — no violations in the plan's prescribed code; the one deliberate rule-13 deviation (`!== undefined` in the sanitizer) is documented with its D3/D6-driven rationale and flagged to conventions reviewers.

## update_columns / transactions

None used. ✓ (Pipeline rule 25 N/A.)

## Violations found

None.
