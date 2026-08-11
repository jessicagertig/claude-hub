# Org Inheritance and Persistence — Pass 2

## Pass 1 correction verification
The F4 amendment (Files-list header count) touches the file inventory this angle relies on; verified the corrected header "(6 backend + 9 frontend incl. posthog.ts + schema)" now matches the itemized list (items 9–14 backend, 15–22 frontend, 23 schema, 24 posthog.ts) and the Estimated-scope section ("6 backend files edited", "Total: 16 modified files"). Internally consistent. ✓

## Fresh scrutiny
- Migration blocks re-read against D6 one more time: `add_column` only; `:string`/`:string`/`:jsonb`/`:string`; zero `default:`, zero `null:`, zero `index:`; class names `AddAttributionColumnsToUsers`/`AddAttributionColumnsToOrganizations` match the file names; `<ts2>` strictly greater than `<ts1>` enforced. ✓
- B2.2's migrate commands re-checked against the global DB-safety allowlist (db:migrate allowed; the four prohibited alternatives named and avoided). ✓
- B4.1 insertion point re-verified against live lines 26–35 of `organizations_controller.rb`: copy lines sit between the `created_via` copy (31) and `is_claimed` (32), before `authorize` (33) and the `if @organization.save` check — no rule-12 interaction, no Pundit change. ✓
- B4.2 threat case re-checked: `utm_source` in the request body is both unpermitted (`organization_params` untouched) and unread (values only from `current_user`); T5.4 pins it. ✓
- Zero-model-edit invariant: B2.4 + Do-NOT-touch + V8 cover `organization.rb` (repo edit restriction) and limit `user.rb` to the B6 edit. ✓

## Completeness sweep (spec §3, §4.4, D5/D6)
All requirements mapped (migrations, schema commit, no backfill, copy-at-creation, nil→nil, no serializer exposure). Nothing dropped; Pass 1 amendments introduced no inconsistency here.

## Findings
No issues found.

## Amendments Applied
None.
