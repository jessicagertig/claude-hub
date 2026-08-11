# Org Inheritance and Persistence — Pass 1

## Fact Check

| Claim (plan) | Verified against | Result |
|---|---|---|
| Migration blocks: 4 × `add_column`, types string/string/jsonb/string, NO default, NO `null: false`, NO index; `ActiveRecord::Migration[6.1]`; class names match file names | plan B1.1/B2.1 code blocks vs D6 and the migration analog | ✓ internally consistent; exactly the D6 column set |
| Analog migration `20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb` has `default: 0, null: false` on counters (the thing NOT to copy) | live file | ✓ exact (`# frozen_string_literal: true` header also matches plan blocks) |
| `settings` jsonb on users and organizations is `default: {}, null: false` (deliberate contrast) | db/schema.rb users (line ~1262) and organizations (line ~1039) | ✓ |
| No `utm_*` columns on users/organizations today; only `ahoy_visits` | db/schema.rb | ✓ re-verified (C.1) |
| `organizations_controller.rb:31` — `@organization.created_via = current_user.created_via`; line 32 `is_claimed = true`; line 33 `authorize @organization` | live file 26–49 | ✓ exact — B4.1 insertion point ("immediately after line 31 and before `is_claimed`") is correct |
| `organization_params` uses `params.require(:organization)` and does not include the four values | live file / PR #3005 diff context | ✓ — B4.2's "unpermitted AND unread" holds; copy lines precede the existing `if @organization.save` check (rule 12 untouched) |
| `db:migrate` on dev + `RAILS_ENV=test` db:migrate; NO `db:test:prepare`/`db:schema:load`/`db:setup`/`db:reset` | global CLAUDE.md DB-safety rules | ✓ compliant (B2.2, V1, Risk 5) |
| No model edits: `organization.rb` zero diff; `user.rb` only the `from_omniauth` change | plan B2.4, Files list, Do-NOT-touch | ✓ consistent with spec §3 and the repo's organization.rb edit restriction |
| Open-PR conflict: newest PR #3035 `messaging-improvements` (2026-06-05); `recruiter-links` #3005 touches `organization_params` only (adds `:enable_recruiter_submission_links`, reformats), not `#create` | `gh pr list` + `gh pr diff 3005` | ✓ exact — no overlap with the four copy lines in `create` |

## Completeness (spec §3, §4.4, D5/D6)

- Two migrations, `<ts2>` > `<ts1>` — B1/B2 ✓
- schema.rb regenerated and committed — B2.3 ✓
- No backfill, no data migration — B2.3 ✓
- Copy-at-creation from `current_user`, nil→nil, no fallback — B4 ✓
- `organization_params` unmodified; `authorize @organization` untouched — B4.2 ✓
- No serializer exposure (`Api::V1::SessionSerializer`/`Api::V1::OrganizationSerializer` zero diff) — Do-NOT-touch + V8 ✓

## Findings

No issues found.

## Amendments Applied

None required for this angle.
