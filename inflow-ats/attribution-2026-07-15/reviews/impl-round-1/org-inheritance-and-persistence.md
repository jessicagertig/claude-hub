# org-inheritance-and-persistence — Round 1

## Verification performed

- **Migrations:** `20260715233505_add_attribution_columns_to_users.rb` and `20260715233506_add_attribution_columns_to_organizations.rb` — identical column sets (`utm_source` string, `utm_campaign` string, `utm_data` jsonb, `internal_ref` string), plain `add_column`, NO `default:`, NO `null: false`, NO index (D6 — deliberately unlike the sibling `settings` jsonb `default: {}, null: false`). Organizations timestamp strictly greater than users timestamp. Class names match file names. `# frozen_string_literal: true` present; rubocop clean on both files. No `db/data/` migration (no backfill — D6).
- **schema.rb:** version bumped `2026_06_11_120003` → `2026_07_15_233506`; the four columns appear on BOTH tables as bare `t.string`/`t.jsonb` (no options); no other schema drift leaked into the regenerated file (diff contains only the version line + 8 column lines). `RAILS_ENV=test bundle exec rails db:migrate:status` shows both migrations `up` on the test DB.
- **Copy-at-creation** (`organizations_controller.rb#create`): the four copy lines sit immediately after the existing `@organization.created_via = current_user.created_via` and before `@organization.is_claimed = true`, exactly matching the analog's shape (direct setter from `current_user`). `authorize @organization` unchanged. `organization_params` NOT modified — the values never come from the request.
- **Anti-tamper proven by execution:** `organizations_controller_spec.rb` posts `organization: { name: 'Tamper Org', utm_source: 'attacker' }` and asserts the created Organization's `utm_source` still equals the `current_user` value — passed. Nil user columns → nil org columns (including `utm_data` `be_nil`) — passed.
- **No model edits:** `app/models/organization.rb` has zero diff (repo rule respected). `app/models/user.rb` touched ONLY for `from_omniauth` (no validations, enums, or `attr_accessor` for the four columns anywhere).
- **No serializer exposure:** zero diff under `app/serializers/` (the 24-file commit list contains no serializer, policy, or job file); `Api::V1::SessionSerializer` and `Api::V1::OrganizationSerializer` untouched.

## Findings

No issues found.
