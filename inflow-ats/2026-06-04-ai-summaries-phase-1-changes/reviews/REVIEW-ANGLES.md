# Review Angles — AI Summaries Phase 1 Changes

Generated from: SPEC.md
Date: 2026-06-04

---

## Subsystems touched

**Backend — models:**
- `app/models/job.rb` (enum rename, cascade method rename)
- `app/models/organization.rb` (settings key rename, `process_ai_credit_resets`, Sentry in `create_ai_credit_state_if_needed`)
- `app/models/organization_ai_credit_balance.rb` (remove overdue chain)
- `app/models/organization_ai_credit_purchase.rb` (add `CREDIT_PACKS_BY_LOOKUP_KEY`, class methods, relax validations)
- `app/models/textract_result.rb` (rename broadcast method, rename action string, add `errorMessage`, remove `saved_change_to_id?`)

**Backend — controllers (deleted and created):**
- `app/controllers/api/v1/ai_credits_controller.rb` (deleted)
- `app/controllers/api/v1/ai_credit_subscriptions_controller.rb` (deleted)
- `app/controllers/api/v1/organization_ai_credit_balance_controller.rb` (new)
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (new)
- `app/controllers/api/v1/jobs_controller.rb` (strong params rename)
- `app/controllers/api/v1/organizations_controller.rb` (permitted settings params rename)

**Backend — policies (renamed):**
- `app/policies/organization_ai_credit_balance_policy.rb` (was `ai_credit_policy.rb`)
- `app/policies/organization_ai_credit_purchase_policy.rb` (was `ai_credit_subscription_policy.rb`)

**Backend — serializers:**
- `app/serializers/api/v1/job_serializer.rb` (field rename)

**Backend — jobs:**
- `app/jobs/stripe_webhook_handler_job.rb` (new `invoice.paid` branch, new `checkout.session.completed` branch, remove `mode == 'payment'` branch, `AiCreditPacks` → `OrganizationAiCreditPurchase`)
- `app/jobs/bulk_generate_ai_summaries_job.rb` (swap `discard_on`/`retry_on` order, add `notify_complete`/`notify_failure`)

**Backend — mailers:**
- `app/mailers/ai_credit_notification_mailer.rb` (fix `is_admin?` → `is_admin`, rename templates)
- `app/mailers/bulk_job_application_ai_summary_result_mailer.rb` (new)

**Backend — interactors:**
- `app/interactors/apply_ai_credit_purchase.rb` (remove `apply_subscription` creation branch)
- `app/interactors/apply_ai_credit_refund.rb` (`.last`, remove `.reload` calls)
- `app/interactors/reset_daily_ai_credits.rb` (add Flipper guard)
- `app/interactors/validate_ai_summary_generation.rb` (error string change)
- `app/interactors/consume_ai_credits.rb` → `app/interactors/create_ai_credit_balance_transaction.rb` (rename)

**Backend — services:**
- `app/services/plan_feature_gate.rb` (remove comment, fix fallback, env var constant)
- `app/services/ai_job_application_action/summary/generate.rb` (remove `prompt_text`)
- `app/services/role_category_groups.rb` (deleted)

**Backend — initializers / config:**
- `config/initializers/ai_credit_packs.rb` (deleted)
- `config/initializers/01_variables.rb` (add `AI_DAILY_CREDIT_ALLOCATION`)
- `config/routes.rb` (replace AI credit routes)

**Backend — migrations (in-place edits):**
- `db/migrate/20260408040701_add_auto_generate_ai_summaries_to_jobs.rb` (rename file+class+column)
- `db/migrate/20260311120000_create_ai_job_application_summaries.rb` (remove `prompt_text`)
- `db/data/20260408040802_add_ai_settings_to_existing_organizations.rb` (rename settings key)

**Backend — rake tasks:**
- `lib/tasks/ai_credits.rake` (rename method call)
- `lib/tasks/ai_bulk_extract.rake` (remove `prompt_text:`)
- `lib/tasks/AI_TASKS_README.md` (new documentation file)

**Frontend — components:**
- `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx` (sidebar restructure, route consolidation)
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AccountPlatoAiContainer.tsx` (new)
- `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx` (replace hooks, remove hardcoded tiers)
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` (rename case, add failure case)
- `app/javascript/ats/src/views/accountAdmin/OrganizationAiSettings.tsx` (state key rename)
- `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx` (field and enum value renames)

**Frontend — hooks (deleted and created):**
- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` (new consolidated file)
- `app/javascript/shared/queryHooks/useAiCreditSubscription.ts` (deleted)
- `app/javascript/shared/queryHooks/useSubscribeToAiCreditPack.ts` (deleted)
- `app/javascript/shared/queryHooks/usePurchaseAiCreditTopUp.ts` (deleted)
- `app/javascript/shared/queryHooks/useCancelAiCreditSubscription.ts` (deleted)

**Frontend — types and helpers:**
- `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts` (rename payload, add bulk failed payload)
- `app/javascript/shared/types/aiJobApplicationSummary.ts` (reconcile `AiResumeStructuredData`)
- `app/javascript/shared/types/organization.ts` (rename settings key)
- `app/javascript/ats/src/lib/newLookups.ts` (rename enum type and values)
- `app/javascript/shared/lib/planHelpers.ts` (add credits constant and transform)

**Specs:**
- `spec/mailers/ai_credit_notification_mailer_spec.rb` (new)
- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` (new)
- `spec/support/ai_credits_test_helpers.rb` (add helper)
- `spec/initializers/ai_credit_packs_spec.rb` (deleted)
- `spec/models/organization_ai_credit_purchase_spec.rb` (updated)
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` (updated)
- `spec/interactors/apply_ai_credit_purchase_spec.rb` (updated)
- `spec/interactors/apply_ai_credit_refund_spec.rb` (updated)
- `spec/interactors/cancel_ai_credit_subscription_spec.rb` (updated)
- `spec/interactors/consume_ai_credits_spec.rb` → `spec/interactors/create_ai_credit_balance_transaction_spec.rb` (renamed)
- `spec/interactors/credit_consumption_with_notifications_spec.rb` (updated)
- `spec/policies/ai_credit_policy_spec.rb` → `spec/policies/organization_ai_credit_balance_policy_spec.rb` (renamed)

---

## Full-stack analogs

### Analog 1: Controller restructuring + hook consolidation

**Billing checkout → webhook → subscription linking:**
- Frontend: `useBilling` hooks → `AccountBilling.tsx`
- API: `POST /billing/checkout` → `BillingController#checkout`
- Backend: `billing_controller.rb:113` records `stripe_checkout_session_id` on `Organization`
- Webhook: `stripe_webhook_handler_job.rb:67-73` links `stripe_subscription_id` on `checkout.session.completed`

**The new credit-pack flow mirrors this exactly:** `OrganizationAiCreditPurchasesController#checkout` creates the `OrganizationAiCreditPurchase` row (instead of updating `Organization`), then `checkout.session.completed` links `stripe_subscription_id` on the purchase record.

**Hook pattern:** `useOrganizationAiCreditBalance.ts` is the direct hook pattern — `useQuery`, `apiGet`, named query key array, `refetchOnWindowFocus: false`. The consolidated `useOrganizationAiCreditPurchase.ts` replicates this shape.

### Analog 2: Stripe webhook invoice.paid branching

**Existing `invoice.paid` side-branches:**
- `stripe_webhook_handler_job.rb:206-235` — `board_wwr_listing_id` / `board_what_jobs_listing_id` metadata branches

The new `ai_credit_pack_top_up` branch follows the same pattern: check `object.metadata&.[]('...')`, process, then fall through only when none match.

### Analog 3: Mailer pattern

**JobResumeExportMailer:**
- Args by ID, `User.find(user_id)`, `message_params` hash, `Emails::SendTemplateEmail.new(message_params).send`
- `to: [{ name: "#{@user.first_name} #{@user.last_name}".strip, email: @user.email }]`

`BulkJobApplicationAiSummaryResultMailer` follows this exactly.

### Analog 4: Tab consolidation

**AccountIntegrationsContainer.tsx:**
- `Styled.Container` (flex, height 100%)
- `Styled.Sidebar` (40vw / 33.333% at lg, border-right, padding-top 0.375rem)
- `Styled.Content` (66.666%, overflow-y auto)
- `useAuthorization({ adminOnly: true })` guard
- `Switch` / `Route` / `Redirect`

`AccountPlatoAiContainer` replicates these styled components exactly.

**Priority rule:** Where the full-stack analog deviates from convention, the analog wins. Note the deviation so the reviewer doesn't flag it.

---

## Angles

### angle-1: stripe-webhook-and-checkout-hardening

**What this covers:** The entire Stripe event flow for credit pack top-ups and subscriptions — `invoice.paid` branch for top-up credits (Note #4), `checkout.session.completed` branch for subscription linking (Note #9B-5), removal of `mode == 'payment'` branch, `invoice_creation` addition, and `apply_subscription` change.

**Files across all layers:**
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (new)
- `app/jobs/stripe_webhook_handler_job.rb`
- `app/interactors/apply_ai_credit_purchase.rb`
- `app/models/organization_ai_credit_purchase.rb` (validation relaxation)
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`
- `spec/interactors/apply_ai_credit_purchase_spec.rb`

**Analog files for comparison:**
- `app/controllers/api/v1/board_wwr_listings_controller.rb` lines 101-110 — `invoice_creation` block
- `app/controllers/api/v1/billing_controller.rb` line 113 — record-at-checkout pattern
- `app/jobs/stripe_webhook_handler_job.rb` lines 206-235 — existing `invoice.paid` metadata branches
- `app/jobs/stripe_webhook_handler_job.rb` lines 64-73 — subscription linking pattern

**Convention context:** Method-level rescue, not `begin` blocks. The `checkout.session.completed` AI subscription branch must use `return` to prevent base-plan handling. The `else` branch in `handle_credit_pack_invoice_paid` is removed; missing purchase → fail.

---

### angle-2: controller-restructuring-and-route-alignment

**What this covers:** Deletion of two old controllers, creation of two new ones, policy renames, route replacement, `show` response shape change (wrapped → direct), `AiCreditPacks` → `OrganizationAiCreditPurchase` class-method migration.

**Files across all layers:**
- `app/controllers/api/v1/organization_ai_credit_balance_controller.rb` (new)
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (new)
- `config/routes.rb`
- `app/policies/organization_ai_credit_balance_policy.rb` (renamed)
- `app/policies/organization_ai_credit_purchase_policy.rb` (renamed)
- `app/models/organization_ai_credit_purchase.rb`
- `app/jobs/stripe_webhook_handler_job.rb` (`AiCreditPacks` references)

**Analog files for comparison:**
- `app/controllers/api/v1/ai_credits_controller.rb` — `render_one` pattern
- `app/controllers/api/v1/ai_credit_subscriptions_controller.rb` — action shapes
- `config/initializers/ai_credit_packs.rb` — methods to migrate

**Convention context:** One params method per controller. `prices` renders raw Stripe data. Pundit authorization: `checkout`, `purchase_top_up`, `cancel` delegate to `BillingPolicy`, not the new purchase policy.

---

### angle-3: hook-consolidation-and-response-shape-change

**What this covers:** Deletion of four hook files, new consolidated `useOrganizationAiCreditPurchase.ts`, `AccountBillingAiCredits.tsx` refactor removing hardcoded tiers, `aiCreditPrices` transform in `planHelpers.ts`.

**Files across all layers:**
- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` (new)
- `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx`
- `app/javascript/shared/lib/planHelpers.ts`

**Analog files for comparison:**
- `app/javascript/shared/queryHooks/useOrganizationAiCreditBalance.ts` — `useQuery` shape
- `app/javascript/shared/queryHooks/useSubscribeToAiCreditPack.ts` — `useMutation` shape

**Convention context:** Response shape changes from `subscriptionData?.aiCreditSubscription` to `subscriptionData` directly. Query key changes to `["organizationAiCreditPurchase"]`. Params key changes to `{ organizationAiCreditPurchase: { stripePriceLookupKey } }`. `aiCreditPrices` uses camelCased Stripe fields (`p.lookupKey`).

---

### angle-4: enum-rename-cascade

**What this covers:** `auto_generate_ai_summaries_setting` → `auto_generate_ai_summaries` rename, value renames (`inherit/on/off` → `default/enabled/disabled`), org settings key rename, cascade method rename. Touches 9+ files across backend and frontend.

**Files across all layers:**
- `app/models/job.rb`
- `app/serializers/api/v1/job_serializer.rb`
- `app/controllers/api/v1/jobs_controller.rb`
- `app/models/organization.rb`
- `app/controllers/api/v1/organizations_controller.rb`
- `app/models/textract_result.rb`
- `app/javascript/ats/src/lib/newLookups.ts`
- `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx`
- `app/javascript/shared/types/organization.ts`
- `app/javascript/ats/src/views/accountAdmin/OrganizationAiSettings.tsx`
- `db/migrate/20260408040701_add_auto_generate_ai_summaries_to_jobs.rb`
- `db/data/20260408040802_add_ai_settings_to_existing_organizations.rb`

**Analog files for comparison:**
- `app/javascript/ats/src/lib/newLookups.ts` — current enum values to replace
- `app/javascript/shared/types/organization.ts` — current settings interface

**Convention context:** The org method `auto_generate_ai_summaries_enabled` intentionally has no `?` — it reads a settings hash, not a boolean column. The cascade method `should_auto_generate_ai_summaries?` uses the new predicates.

---

### angle-5: bulk-job-completion-notifications

**What this covers:** `retry_on`/`discard_on` declaration order swap (Note #25), `notify_complete`/`notify_failure` methods (Note #13), new mailer, new WebSocket action, TDD requirement.

**Files across all layers:**
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/mailers/bulk_job_application_ai_summary_result_mailer.rb` (new)
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`
- `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts`
- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` (new)

**Analog files for comparison:**
- `app/mailers/job_resume_export_mailer.rb` — exact mailer pattern
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` `AI_SUMMARY_BULK_COMPLETE` case — existing handler pattern

**Convention context:** Known failure pattern #4 — every mailer call must chain `.deliver_later`. Spec must stub mailer to return `instance_double(ActionMailer::MessageDelivery)` and verify `.deliver_later`. TDD: spec must fail before code change, pass after without modification.

---

### angle-6: mailer-bug-fixes-and-template-renames

**What this covers:** `is_admin?` → `is_admin` fix (Note #1), template name changes (Notes #20+#38), new mailer spec, new test helper.

**Files across all layers:**
- `app/mailers/ai_credit_notification_mailer.rb`
- `spec/mailers/ai_credit_notification_mailer_spec.rb` (new)
- `spec/support/ai_credits_test_helpers.rb`

**Analog files for comparison:**
- `app/mailers/ai_credit_notification_mailer.rb` — `OrganizationUser#is_admin` method exists; `is_admin?` does not

**Convention context:** This mailer takes an `Organization` object (not an ID), unlike `JobResumeExportMailer`. The `NoMethodError` raises inside Sidekiq delivery, not at the interactor call site. Spec stubs `Emails::SendTemplateEmail`.

---

### angle-7: plato-ai-tab-consolidation

**What this covers:** New `AccountPlatoAiContainer.tsx`, `AccountContainer.tsx` sidebar and route changes, admin-only gate.

**Files across all layers:**
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AccountPlatoAiContainer.tsx` (new)
- `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx`

**Analog files for comparison:**
- `app/javascript/ats/src/views/accountAdmin/accountIntegrations/AccountIntegrationsContainer.tsx` — exact pattern to replicate

**Convention context:** Emotion theme utilities (known failure pattern #1) — use `t.text.sm` standalone, not inside `font-size:`. Styled component labels must match component name. `exact={false}` on the route. Default redirect to `${match.url}/settings`. Non-admins: remove from `memberPathNames` AND guard inside container.

---

### angle-8: model-and-service-cleanups

**What this covers:** All smaller correctness and cleanup changes: `ApplyAiCreditRefund` query direction and `.reload` removal, overdue chain removal, `ResetDailyAiCredits` Flipper guard, `PlanFeatureGate` fallback fix, Sentry addition, `prompt_text` removal, `ConsumeAiCredits` rename, WebSocket action rename, `saved_change_to_id?` removal, comment removal, `AiResumeStructuredData` reconciliation, `RoleCategoryGroups` deletion.

**Files across all layers:**
- `app/interactors/apply_ai_credit_refund.rb`
- `app/models/organization_ai_credit_balance.rb`
- `app/models/organization.rb`
- `lib/tasks/ai_credits.rake`
- `app/interactors/reset_daily_ai_credits.rb`
- `app/services/plan_feature_gate.rb`
- `config/initializers/01_variables.rb`
- `app/models/textract_result.rb`
- `app/interactors/validate_ai_summary_generation.rb`
- `app/interactors/consume_ai_credits.rb` → `app/interactors/create_ai_credit_balance_transaction.rb`
- `app/interactors/notify_zero_ai_credits.rb` (comment only)
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`
- `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts`
- `app/javascript/shared/types/aiJobApplicationSummary.ts`
- `app/services/ai_job_application_action/summary/generate.rb`
- `lib/tasks/ai_bulk_extract.rake`
- `app/services/role_category_groups.rb` (deleted)

**Analog files for comparison:**
- `app/interactors/validate_ai_summary_generation.rb` line 42-43 — `Flipper.enabled?` pattern for `:AI_DAILY_CREDITS` guard
- `app/services/plan_feature_gate.rb` lines 135-137 — `monthly_ai_credit_allocation` fallback pattern

**Convention context:** `saved_change_to_id?` removal is safe — AR dirty tracking covers new-record creates. `AI_CREDITS_EXHAUSTED` rename must also update payload type import. `AiResumeStructuredData` evaluative fields use optional `?` (not `| null`).

---

## Always-on checks

### A1 — Source accuracy

Every file path and identifier in the spec must match the actual codebase. Verify:
- `OrganizationUser#is_admin` exists (not `is_admin?`)
- Four real Stripe lookup keys replace all six fabricated keys everywhere
- `Variables::AI_DAILY_CREDIT_ALLOCATION` is referenced correctly
- `handle_credit_pack_invoice_paid` `else` branch is fully removed

### A2 — Test coverage

Verify all spec requirements from the Test Requirements section:
- Mailer spec covers all assertion groups
- Bulk job spec covers all assertion groups with TDD evidence
- Mailer stubs use `instance_double(ActionMailer::MessageDelivery)` with `.deliver_later` verification
- Renamed spec files reflect new class names internally
- `spec/models/organization_ai_credit_purchase_spec.rb` has pack coverage

### A3 — Ripple-site completeness for renames

For each rename, verify no stale reference remains:
- `auto_generate_ai_summaries_setting` → `auto_generate_ai_summaries` (9+ files)
- `AiCreditPacks.*` → `OrganizationAiCreditPurchase.*` (3+ call sites in webhook job)
- `ConsumeAiCredits` → `CreateAiCreditBalanceTransaction` (2 specs, 1 model, 1 interactor comment)

### A4 — Full-stack analog completeness

For each new construct, verify the analog was followed:
- `BulkJobApplicationAiSummaryResultMailer` — args by ID, `Emails::SendTemplateEmail`, correct `from`/`tags`/`template_version`
- `AccountPlatoAiContainer` — styled component dimensions, `Redirect` to relative path
- New controllers — method-level rescue, one params method, `render_one` for show
