# Always-on checks — Round 1

## A1 — Source accuracy

- `OrganizationUser#is_admin` exists at line 54 — confirmed (no `is_admin?` predicate)
- Four real Stripe lookup keys specified in spec match approved decisions — confirmed
- `Variables::AI_DAILY_CREDIT_ALLOCATION` — the spec correctly states to add it to `01_variables.rb` and reference from `PlanFeatureGate`; current `01_variables.rb` has no `AI_DAILY_CREDIT` entry — confirmed
- `handle_credit_pack_invoice_paid` `else` branch at lines 483-489 is correctly identified for removal — confirmed

No findings.

## A2 — Test coverage

- Mailer spec covers all assertion groups (recipients, message_params for both methods, send invocation) — confirmed in spec
- Bulk job spec covers retry/discard assertions, completion/failure broadcasts, `.deliver_later` verification — confirmed
- Known failure pattern #4 compliance: spec explicitly requires `instance_double(ActionMailer::MessageDelivery)` with `.deliver_later` verification — confirmed
- Renamed spec files correctly list class name updates — confirmed
- `spec/models/organization_ai_credit_purchase_spec.rb` pack coverage addition — confirmed

No findings.

## A3 — Ripple-site completeness for renames

**`auto_generate_ai_summaries_setting` → `auto_generate_ai_summaries`:**
All 9+ files verified present in the spec. See angle-4 for detail.

**`AiCreditPacks.*` → `OrganizationAiCreditPurchase.*`:**

[HIGH] Missing: `app/models/organization_ai_credit_purchase.rb` line 14 — `AiCreditPacks.registered_keys` in validation inclusion. Captured in angle-2 finding 1.

Remaining sites verified:
- `stripe_webhook_handler_job.rb` — 3 references (lines 111, 151, 242)
- `apply_ai_credit_purchase.rb` — 2 references (lines 48, 95)
- Old controllers being deleted — references go away with the files
- `spec/initializers/ai_credit_packs_spec.rb` — being deleted
- `spec/interactors/apply_ai_credit_purchase_spec.rb` — 2 references (lines 80, 111)

**`ConsumeAiCredits` → `CreateAiCreditBalanceTransaction`:**
All sites verified: 1 model, 1 interactor comment, 2 specs, 2 logger strings.

## A4 — Full-stack analog completeness

- `BulkJobApplicationAiSummaryResultMailer` follows `JobResumeExportMailer` exactly: args by ID, `Emails::SendTemplateEmail`, `from`/`to`/`tags`/`template_version` — verified pattern match
- `AccountPlatoAiContainer` follows `AccountIntegrationsContainer` — verified analog exists
- New controllers use method-level rescue (core rule #1), one params method (core rule #5), `render_one` for show — specified correctly

No additional findings.
