# Always-on checks — Round 5

## A1 — Source accuracy

- `OrganizationUser#is_admin` exists (not `is_admin?`): VERIFIED -- `select(&:is_admin)` in mailer
- Four real Stripe lookup keys replace all six fabricated keys everywhere: VERIFIED -- grep shows only the four real keys
- `Variables::AI_DAILY_CREDIT_ALLOCATION` is referenced correctly: VERIFIED -- `DAILY_AI_CREDIT_ALLOCATION = Variables::AI_DAILY_CREDIT_ALLOCATION` in `plan_feature_gate.rb`
- `handle_credit_pack_invoice_paid` `else` branch is fully removed: N/A -- the entire method was rewritten from scratch (which is itself an out-of-spec concern, see spec-compliance F6)

## A2 — Test coverage

- Mailer spec covers all assertion groups: VERIFIED
- Bulk job spec covers all assertion groups with TDD evidence: VERIFIED (retry/discard ordering test exists)
- Mailer stubs use `instance_double(ActionMailer::MessageDelivery)` with `.deliver_later` verification: VERIFIED
- Renamed spec files reflect new class names internally: VERIFIED
- `spec/models/organization_ai_credit_purchase_spec.rb` has pack coverage: VERIFIED -- `CREDIT_PACKS_BY_LOOKUP_KEY` describe block present

## A3 — Ripple-site completeness for renames

- `auto_generate_ai_summaries_setting` -> `auto_generate_ai_summaries`: VERIFIED -- zero stale references (excluding out-of-spec migration)
- `AiCreditPacks.*` -> `OrganizationAiCreditPurchase.*`: VERIFIED -- zero stale references
- `ConsumeAiCredits` -> `CreateAiCreditBalanceTransaction`: VERIFIED -- zero stale references

## A4 — Full-stack analog completeness

- `BulkJobApplicationAiSummaryResultMailer` -- args by ID: VERIFIED. `Emails::SendTemplateEmail`: VERIFIED. Correct `from`: VERIFIED (`EMAIL_NOTIFICATIONS_ADDRESS`). `tags`: VERIFIED. `template_version`: VERIFIED (`'initial'`).
- `AccountPlatoAiContainer` -- styled component dimensions match `AccountIntegrationsContainer`: VERIFIED. `Redirect` to relative path: VERIFIED. `useAuthorization({ adminOnly: true })`: VERIFIED.
- New controllers -- `render_one` for show: VERIFIED. One params method: VERIFIED. Stripe error rescue with Sentry: Present (not in analog, but acceptable).
