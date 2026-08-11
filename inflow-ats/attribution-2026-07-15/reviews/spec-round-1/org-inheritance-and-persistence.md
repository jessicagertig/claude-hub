# org-inheritance-and-persistence — Round 1

Verified against live source: `db/schema.rb` (users: `settings jsonb default: {} null: false`, `created_via integer default: 0`, `partner_source integer` — same on organizations; **no existing `utm_*`/`internal_ref` columns on either table**; the repo's only utm columns live on `ahoy_visits` (schema lines 104–108), no name conflict), `organizations_controller.rb#create` (lines 26–49: `@organization.created_via = current_user.created_via` at line 31, `authorize @organization` at 33 AFTER attribute assignment — the copied values are covered by the existing authorize placement; `organization_params` untouched so request-supplied `utm_source` in the org-create body is never read), migration analog `db/migrate/20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb` (`ActiveRecord::Migration[6.1]`, plain `add_column`; its `default: 0, null: false` counters are precisely what D6 forbids here), `cursor_rules/backend/migrations.md` (read in full), core_critical_rules line 340 ("Do not automate edits to `app/models/organization.rb`" — spec §3 note matches).

## Findings

- F1 [LOW] `cursor_rules/backend/migrations.md` rule 3 says "include proper indices for … commonly queried fields." The four columns are unindexed by D6 (binding). Attribution columns are written once and read by ad-hoc analysis, not app queries — no conflict in substance. Recorded so the impl-review conventions fan-out doesn't re-open it. No amendment.

## Verified-clean

- Two migrations, identical column sets, string/string/jsonb/string, no defaults, nullable, no index — restates D6 exactly. The deliberate contrast with the sibling `settings` jsonb (`default: {}, null: false`) is real (schema verified) and correctly called out.
- Copy-at-creation is structurally identical to the `created_via` analog copy (assignment block, same actor, same source `current_user`, before `authorize`/`save`).
- Nil user columns → nil org columns falls out of plain attribute copy — no fabrication anywhere (rule 10).
- No model edits: `organization.rb` untouched (repo rule); `user.rb` touched only for `from_omniauth`. No validations/enums/`attr_accessor` — columns are plain attributes.
- No serializer exposure: spec §7.6 explicitly keeps `Api::V1::SessionSerializer`/`Api::V1::OrganizationSerializer` zero-diff.
- No backfill/data migration — D6; `migrations.md` data-migration section n/a.
- Boolean-prefix rule n/a (no booleans). Single-purpose rule satisfied (one table per migration).

## Amendments Applied

- None.
