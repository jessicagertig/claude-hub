# operational-concerns (always-on impl) — Round 1

- N+1 avoidance: mailer uses `.includes(:user)` before mapping to `{ name, email }` — one query for org users, one for users. Matches the analog. ✓
- Empty-recipients guard: `return unless recipients.any?` prevents sending an email with an empty `to:` in both `complete` and `failed`. ✓
- Error handling: no new rescue paths needed; the interactor/controller error branches (`render_errors`, `render_general_errors`) are unchanged.
- Performance: gate change is a single boolean AND; no added queries in the interactor. Modal copy is pure render logic.
- Deployment: MANUAL STEP — Jessica must paste both updated all-stages `.mjml` templates into Mailgun after merge (the polymer-mail edits are working-tree/source only; Mailgun-hosted copies are not touched by code). This is documented in SPEC 1.6 and plan B1.6.
- No logging regressions (the analog mailer does not log; none removed).

## Findings
No issues found. (Operational note, not a defect: the Mailgun template paste is a required post-merge manual deploy step, already recorded in the spec/plan.)
