# CLAUDE.md / Safety Compliance — Pass 2 (post-amendment re-verify)

Re-verified after the Pass 1 amendments (T4.1 devise.mapping, three line-ref/count corrections):

- **Database safety:** unchanged — the amendments touched no command. `db:migrate` (dev + `RAILS_ENV=test`) remain the only DB operations; prohibitions on `db:test:prepare`/`db:schema:load`/`db:setup`/`db:reset` still stated in B2.2 and Risk 5. No psql, no `DATABASE_URL`, no `.env`, no data migration. ✓
- **The T4.1 amendment adds spec-file mechanics only** — a `before` block setting `@request.env['devise.mapping']` in a new test file. No production-code impact, no migration impact, no authorization impact. ✓
- **Branch/commit rules:** unchanged (attribution-work; `nvm use && git commit` outside sandbox; never `--no-verify`; commit before review per pipeline rule 15). ✓
- **Breaking-change mitigations:** unchanged (B6.3 census + re-grep; T3.5/T4.3 keyword pins — T4.3 now actually executable thanks to the T4.1 fix). ✓
- **Authorization/policies:** no changes anywhere; `authorize @organization` untouched; unauthenticated signup paths by design. ✓
- **cursor_rules:** amendments introduce no new code patterns; pass-2 conventions angle clean. ✓

## Violations found

None.
