# Impl round 1 — migrations-and-schema-hygiene

## Migrations

- `db/migrate/20260724183710_add_attribution_identifier_columns_to_users.rb`: `# frozen_string_literal: true`, `ActiveRecord::Migration[6.1]`, EIGHT bare `add_column :users, <col>, :string` lines — no defaults, no indexes, no null constraints. Shape identical to the analog `20260723222212_add_adroll_click_id_to_users.rb`. Class name matches file name.
- `db/migrate/20260724183711_add_attribution_identifier_columns_to_organizations.rb`: SIX columns only (`ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`) — `google_click_id` and `adroll_first_party_cookie` correctly NOT re-added (they pre-exist on organizations). Timestamp sequenced after the users migration.
- `cursor_rules/backend/migrations.md`: no boolean columns (rule 1 N/A); single-purpose (rule 3); no data migration needed (no backfill by spec). No model edits; `app/models/organization.rb` untouched (hard repo rule) ✓.

## Schema commit hygiene (SPEC §3 HARD rule + pipeline failure pattern 15)

- Reviewed the COMMITTED diff, not the working tree. `git diff b4cb4463a..a0d59115d -- db/schema.rb` contains EXACTLY: the version bump (`2026_07_23_222213` → `2026_07_24_183711`), 6 organization column lines, 8 users column lines. Nothing else — none of the dev-schema corruption was committed.
- `git status --porcelain`: the ONLY working-tree residue is unstaged `db/schema.rb` noise, inspected and confirmed to be the known unrelated dev-database drift (`channel_message_templates.subject`, `channel_messages.subject`/`mailgun_message_id`, `jobs.apply_response_template_subject`, the `stripe_cancel_at_period_end` removal, `textract_results` structured-extraction columns/index). Correctly left unstaged — do NOT stage or "fix" it.
- Single commit in the range (`a0d59115d`); no other uncommitted feature-related change exists — the reviewed code is the code that merges.

## Findings

None. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
