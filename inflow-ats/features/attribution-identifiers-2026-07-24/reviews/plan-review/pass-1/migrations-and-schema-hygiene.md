# Plan review pass 1 — migrations-and-schema-hygiene

Reviewed: plan.md T1-T3, §13, risk 5 against SPEC §3 and live code @ `b4cb4463a`.

## Fact checks performed (all verified live)

- Analog migrations read whole: `20260723222212_add_adroll_click_id_to_users.rb` and `20260723222213_add_adroll_columns_to_organizations.rb` — `# frozen_string_literal: true`, `ActiveRecord::Migration[6.1]`, bare `add_column ... :string`, no defaults/indexes/constraints. T1/T2 skeletons match the shape exactly.
- Column pre-existence in `db/schema.rb`: NONE of `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id` exists anywhere (grep returns zero hits). On organizations (create_table :1033): `google_click_id` :1078, `adroll_click_id` :1093, `adroll_first_party_cookie` :1094. On users (create_table :1250): `adroll_click_id` :1291; neither `google_click_id` nor `adroll_first_party_cookie` present. The 8-users/6-organizations split in T1/T2 is exactly right; re-adding the two existing organization columns would raise on migrate, and the plan says so.
- T3 uses `bundle exec rails db:migrate` only — on the allowed list; no prohibited db commands anywhere in the plan.
- The SPEC §3 HARD hunk-staging rule is carried verbatim into plan §13, restated in T3 and §4's schema.rb entry, and risk 5 directs the impl review at the COMMITTED schema diff (failure pattern 15).
- `app/models/organization.rb` untouched (plan §4 not-touched list) — SPEC §3 "no model changes" plus the hard repo rule.
- Plan §2's note that the schema corruption is not visible in the committed tree matches the spec-review observation (clean at `b4cb4463a`; drift expected on regeneration from the dev database).

## Findings

None. 0 BLOCKER, 0 HIGH, 0 MED, 0 LOW.
