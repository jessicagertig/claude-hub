# spec-round-1 — migrations-and-schema-hygiene

Reviewed against live source, branch `attribution-work-qa`, tip `b4cb4463a` (no drift).

## Verifications (all pass)

1. **Analog migration shape — CONFIRMED.** `db/migrate/20260723222212_add_adroll_click_id_to_users.rb` and `20260723222213_add_adroll_columns_to_organizations.rb` both read exactly: `# frozen_string_literal: true`, `class ... < ActiveRecord::Migration[6.1]`, `def change`, bare `add_column :<table>, :<col>, :string`. SPEC §3's shape claim is accurate.
2. **Existing organization columns — CONFIRMED.** `db/schema.rb:1078` `t.string "google_click_id"` and `db/schema.rb:1094` `t.string "adroll_first_party_cookie"`, both inside `create_table "organizations"` (1033–1249). SPEC §3's "schema line 1078" reference is correct.
3. **No pre-existing collisions — CONFIRMED.** None of `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id` exist anywhere in `db/schema.rb`; `users` (create_table at 1250) has neither `google_click_id` nor `adroll_first_party_cookie`. All eight users-columns and six organizations-columns are genuinely new; no migration will hit a duplicate-column error. (The `utm_source`/`utm_campaign` hits at schema lines 104/108 belong to `ahoy_visits` — unrelated table.)
4. **Analog columns on users — CONFIRMED.** `utm_source` (1287), `utm_campaign` (1288), `utm_data` jsonb (1289), `internal_ref` (1290), `adroll_click_id` (1291).
5. **T2 six-column set — CONFIRMED** consistent with the §3 table (six NEW on organizations, two already-exist).
6. **Migration name collision — NONE.** Existing `20260715233505_add_attribution_columns_to_users.rb` / `20260715233506_add_attribution_columns_to_organizations.rb` yield class names distinct from the proposed `AddAttributionIdentifierColumnsToUsers`/`...ToOrganizations`.
7. **Data migrations — no concern.** No backfill by design; `db/data/` latest is unrelated (`20260622182505`). Schema version line is 13 (`version: 2026_07_23_222213`) — the two new migrations bump only that line plus the new columns.

## Findings

- F1 [LOW] where: SPEC §3 "Schema commit rule" / what: the claim "The development environment's `db/schema.rb` is corrupted with unrelated local diffs" is not currently observable — `git status --porcelain db/schema.rb` and `git diff HEAD -- db/schema.rb` are both EMPTY on the live tree (schema.rb is clean at review time) / evidence: both commands returned no output at tip `b4cb4463a` / fix: none required — the corruption presumably materializes when `db:migrate` (T3) regenerates schema.rb from the drifted dev database, which is exactly the moment the HARD hunk-staging rule protects. The rule is Jessica's and stands; note is informational only so the implementer isn't confused by a clean pre-migrate tree.

No MED/HIGH/BLOCKER issues found.

## Amendments Applied

None — orchestrator applies amendments. Recommended: none required (F1 is note-only; optionally append to §3 "the corruption appears when db:migrate regenerates schema.rb from the dev database — the tree may look clean before T3 runs").
