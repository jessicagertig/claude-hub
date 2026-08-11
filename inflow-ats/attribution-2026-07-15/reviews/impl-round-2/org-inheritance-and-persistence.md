# org-inheritance-and-persistence — Round 2

Re-derived fresh.

## Verified

- **Migrations:** two files, one per table, identical column sets (`utm_source` string, `utm_campaign` string, `utm_data` jsonb, `internal_ref` string), NO defaults, nullable, no index — deliberately unlike the sibling `settings` jsonb (`default: {}, null: false`), per D6. Shape matches the `20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb` analog (`# frozen_string_literal: true`, `ActiveRecord::Migration[6.1]`, plain `add_column`, auto-reversible `change`). No backfill, no data migration.
- **schema.rb:** version bumped `2026_06_11_120003` → `2026_07_15_233506`; the four columns appended to `organizations` and `users` with no defaults/constraints — matches the spec table exactly.
- **Copy-at-creation (`organizations_controller.rb#create`):** four assignments from `current_user`, inserted directly after the existing `@organization.created_via = current_user.created_via` and before `authorize @organization` — same shape as the analog copy. `organization_params` NOT modified; values never come from the request.
- **Attacker-controlled param ignored:** the new controller spec's tamper case POSTs `organization: { name: ..., utm_source: 'attacker' }` and asserts the persisted value is the `current_user` value — passes.
- **No model edits:** `app/models/organization.rb` zero-diff (repo rule respected); `user.rb` touched only for `from_omniauth`. No validations/enums/`attr_accessor` added anywhere.
- **No serializer exposure:** `Api::V1::SessionSerializer` / `Api::V1::OrganizationSerializer` zero-diff; `git grep utm_ app/serializers/` matches only the pre-existing `ahoy_visit_serializer.rb` (Ahoy gem visit columns, unrelated, untouched by the diff).
- **Nil propagation:** nil user columns → nil org columns, pinned by the controller spec's nil case. Test DB migrated; 17/17 examples pass.

## Findings

No issues found.
