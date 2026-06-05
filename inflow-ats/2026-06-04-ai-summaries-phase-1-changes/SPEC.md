# SPEC.md — AI Summaries Phase 1 Changes

**Working directory:** `/Users/jessica/claude-hub/inflow-ats/2026-06-04-ai-summaries-phase-1-changes/`
**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`

---

## Summary

This spec covers approximately 30 confirmed changes to the AI summaries and AI credits system, plus one new frontend navigation consolidation. The changes span bug fixes (mailer `NoMethodError`, Stripe webhook misrouting, `retry_on` declaration order), model/enum renames, controller restructuring, Stripe checkout hardening, service refactors, dead-code removal, and a new email notification system for bulk AI summary jobs. The navigation work consolidates three separate AI settings sidebar entries into a single "Plato AI" nested container (admin-only).

No new database migrations are created. All migrations are dev-only features — they are edited in place and re-run.

---

## Stack Scope

**Backend touched:** models (`Job`, `Organization`, `OrganizationAiCreditBalance`, `OrganizationAiCreditPurchase`), controllers (`Api::V1::AiCreditsController`, `Api::V1::AiCreditSubscriptionsController` — both deleted; two new controllers created), policies (`AiCreditPolicy`, `AiCreditSubscriptionPolicy` — renamed), interactors (`ApplyAiCreditRefund`, `ApplyAiCreditPurchase`, `ConsumeAiCredits` — renamed, `ResetDailyAiCredits`, `ValidateAiSummaryGeneration`), jobs (`StripeWebhookHandlerJob`, `BulkGenerateAiSummariesJob`), mailers (`AiCreditNotificationMailer`, new `BulkJobApplicationAiSummaryResultMailer`), services (`PlanFeatureGate`, `AiJobApplicationAction::Summary::Generate`), initializers (`01_variables.rb`; `ai_credit_packs.rb` — deleted), rake tasks (`ai_credits.rake`), migrations and data migrations (in-place edits), routes, `RoleCategoryGroups` service (deleted).

**Frontend touched:** `AccountContainer.tsx`, new `AccountPlatoAiContainer.tsx`, `OrganizationAiSettings.tsx` (moved inside container), `OrganizationAiBilling.tsx` (moved inside container), `OrganizationAiUsage.tsx` (moved inside container), `AccountBillingAiCredits.tsx`, `WebsocketGlobalChannelHandler.tsx`, `aiSummaryWebsocketPayloads.ts`, `aiJobApplicationSummary.ts`, `newLookups.ts`, `organization.ts`, `planHelpers.ts`, query hooks (four consolidated into `useOrganizationAiCreditPurchase.ts`, four individual files deleted), `useOrganizationAiCreditBalance.ts` (path unchanged).

**Specs touched/created:** `spec/mailers/ai_credit_notification_mailer_spec.rb` (new), `spec/support/ai_credits_test_helpers.rb` (add helper), `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` (new), `spec/initializers/ai_credit_packs_spec.rb` (deleted; coverage migrated to `spec/models/organization_ai_credit_purchase_spec.rb`), `spec/models/organization_ai_credit_purchase_spec.rb`, `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`, `spec/interactors/apply_ai_credit_purchase_spec.rb`, `spec/interactors/apply_ai_credit_refund_spec.rb`, `spec/interactors/cancel_ai_credit_subscription_spec.rb`, `spec/interactors/consume_ai_credits_spec.rb` (renamed), `spec/interactors/credit_consumption_with_notifications_spec.rb`, `spec/policies/ai_credit_policy_spec.rb` (renamed).

---

## Data Model Changes

### Migration: `db/migrate/20260408040701_add_auto_generate_ai_summaries_setting_to_jobs.rb`

Edit in place (no new migration timestamp):
- Rename migration filename to `20260408040701_add_auto_generate_ai_summaries_to_jobs.rb`
- Rename migration class to `AddAutoGenerateAiSummariesToJobs`
- Change column name from `auto_generate_ai_summaries_setting` to `auto_generate_ai_summaries` in `add_column :jobs, ...`

The column remains `integer, null: false, default: 0`.

### Migration: `db/migrate/20260311120000_create_ai_job_application_summaries.rb`

Edit in place:
- Remove `t.text :prompt_text` from the `create_table :ai_job_application_summaries` block

Roll back to before this migration, edit it, then re-migrate.

### Data migration: `db/data/20260408040802_add_ai_settings_to_existing_organizations.rb`

Edit in place (do not rename the file):
- Change the `AI_SETTING_DEFAULTS` hash key `default_auto_generate_ai_summaries_enabled:` to `auto_generate_ai_summaries_enabled:`

May need to roll back and re-run.

---

## Backend Changes

### Note #1 — Fix `is_admin?` mailer bug

**File:** `app/mailers/ai_credit_notification_mailer.rb`

In `admin_recipients` (line 62), change `select(&:is_admin?)` to `select(&:is_admin)`.

`OrganizationUser#is_admin` exists; `is_admin?` does not — the current code raises `NoMethodError` inside Sidekiq delivery, silently failing both `low_credits` and `zero_credits` mailers.

**Also in this file (Note #20+#38):** Change the two template name string literals:
- `'ai-credits-low'` → `'user-ai-credit-balance-low'`
- `'ai-credits-zero'` → `'user-ai-credit-balance-zero'`

### Note #2 — Reconcile `AiResumeStructuredData` type

**File:** `app/javascript/shared/types/aiJobApplicationSummary.ts`

Reconcile `AiResumeStructuredData` (and `AiWorkExperience`) to mirror what the backend actually writes into `structured_data`.

**Present fields (typed as present):**
- `name`, `email`, `phone`, `location` → `string | null`
- `links`, `skills`, `certifications` → `string[]`
- `workExperience` → `AiWorkExperience[]`
- `education` → `AiEducation[]`
- `totalMonthsExperience` → `number`

**`AiWorkExperience`:** remove `roleCategory` and `relevantToJobTitle`. Keep `company`, `title`, `startDate`, `endDate`, `description` (`string | null`). `AiEducation` unchanged.

**Remove entirely:** `totalYearsExperience`, `relevantYearsExperience`, `jobTitleRoleCategory`.

**Optional evaluative fields (typed as optional `?`, not `| null`):**
- `roleAnalysis?`, `applicableExperience?`, `gaps?`, `overlapSummary?` → `string`
- `monthsByDomain?` → loose domain-name-keyed map of months (`number` values)
- `assessment?`, `comparison?` → loosely-typed (permissive) objects, NOT deeply mirrored

**Check on apply:** `AiJobApplicationSummaryFeedItem.tsx` is the sole consumer and reads only `workExperience`/`education`/`skills`/`certifications`, so removing the phantom fields breaks no existing reads.

### Note #3 — `ApplyAiCreditRefund` selects oldest credit row

**File:** `app/interactors/apply_ai_credit_refund.rb`

On the `original_credit_row` query, change `.order(:created_at).first` to `.order(:created_at).last`.

**Also (Note #32):** Remove both `.reload` calls in the same file:
- Line ~21: `purchase.organization.organization_ai_credit_balance&.reload` → `purchase.organization.organization_ai_credit_balance`
- Line ~62: `context.purchase = purchase.reload` → `context.purchase = purchase`

### Note #4 — AI credit top-up webhook and invoice creation

**File:** New `OrganizationAiCreditPurchasesController#purchase_top_up` (per Note #9A)

Add `invoice_creation: { enabled: true, invoice_data: { metadata: { organization_id: current_organization.id, stripe_price_lookup_key: lookup_key, ai_credit_pack_top_up: 'true' } } }` to the `Stripe::Checkout::Session.create` call. Pattern: `app/controllers/api/v1/board_wwr_listings_controller.rb` lines 101–110.

**File:** `app/jobs/stripe_webhook_handler_job.rb`

In the `invoice.paid` handler, add a branch keyed on `object.metadata&.[]('ai_credit_pack_top_up') == 'true'` that grants one-off credits using the `organization_id` and `stripe_price_lookup_key` from the invoice metadata. **Place this branch BEFORE the `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` guard at line 204** — an org that buys only a top-up pack (no base plan subscription) would have `stripe_subscription_id` nil, causing the guard to raise before the top-up metadata check is reached. The guard must only fire for invoices that are not top-up credit packs (and not job listing invoices — the existing `board_wwr_listing_id` / `board_what_jobs_listing_id` branches should also be above the guard).

Remove the `object.mode == 'payment'` branch from `checkout.session.completed`. Also remove `OrganizationAiCreditBalance#apply_top_up_checkout` (lines 35–43 of `organization_ai_credit_balance.rb`) — the `mode == 'payment'` branch is its sole caller, so it becomes dead code.

### Note #5 — Rename `auto_generate_ai_summaries_setting` enum and cascade method

**File:** `app/models/job.rb`

Rename enum field `auto_generate_ai_summaries_setting` to `auto_generate_ai_summaries`. Rename values: `inherit` → `default` (0), `on` → `enabled` (1), `off` → `disabled` (2). Keep `_prefix: true`.

Rename cascade method `effective_auto_generate_ai_summaries_enabled?` to `should_auto_generate_ai_summaries?`. Update its body to use the new predicate names (`auto_generate_ai_summaries_enabled?`, `auto_generate_ai_summaries_disabled?`) and the renamed org method (`organization.auto_generate_ai_summaries_enabled`).

**File:** `app/serializers/api/v1/job_serializer.rb` — `:auto_generate_ai_summaries_setting` → `:auto_generate_ai_summaries`

**File:** `app/controllers/api/v1/jobs_controller.rb` — strong params and `job_params.key?` reference: `:auto_generate_ai_summaries_setting` → `:auto_generate_ai_summaries`

**File:** `app/models/organization.rb` — rename method `default_auto_generate_ai_summaries_enabled?` to `auto_generate_ai_summaries_enabled` (no `?`). Update its body: `settings&.dig('default_auto_generate_ai_summaries_enabled')` → `settings&.dig('auto_generate_ai_summaries_enabled')`.

**File:** `app/controllers/api/v1/organizations_controller.rb` — permitted settings params: `:default_auto_generate_ai_summaries_enabled` → `:auto_generate_ai_summaries_enabled`

**File:** `app/models/textract_result.rb` — `effective_auto_generate_ai_summaries_enabled?` → `should_auto_generate_ai_summaries?`

**File:** `app/javascript/ats/src/lib/newLookups.ts` — rename enum values: `"inherit"` → `"default"`, `"on"` → `"enabled"`, `"off"` → `"disabled"`

**File:** `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx` — update field name from `autoGenerateAiSummariesSetting` to `autoGenerateAiSummaries`, update enum values

**File:** `app/javascript/shared/types/organization.ts` — `defaultAutoGenerateAiSummariesEnabled?: boolean` → `autoGenerateAiSummariesEnabled?: boolean`

**File:** `app/javascript/ats/src/views/accountAdmin/OrganizationAiSettings.tsx` — update state key from `defaultAutoGenerateAiSummariesEnabled` to `autoGenerateAiSummariesEnabled`

### Note #6A — Move `AiCreditPacks` into `OrganizationAiCreditPurchase`

**File:** `config/initializers/ai_credit_packs.rb` — delete entirely

**File:** `app/models/organization_ai_credit_purchase.rb` — add `CREDIT_PACKS_BY_LOOKUP_KEY` frozen hash (with the four real packs per Note #9B-1), plus class methods `registered_keys`, `lookup_by_key`, `subscription_key?`, `one_off_key?`, `credit_amount_for_key`.

**Files with `AiCreditPacks.*` references — replace all with `OrganizationAiCreditPurchase.*`:**
- `app/models/organization_ai_credit_purchase.rb` — line 14 validation: `inclusion: { in: ->(_) { AiCreditPacks.registered_keys } }` → `inclusion: { in: ->(_) { OrganizationAiCreditPurchase.registered_keys } }`
- `app/jobs/stripe_webhook_handler_job.rb`
- `app/interactors/apply_ai_credit_purchase.rb`
- New controllers (per Note #9A)

### Note #6B — Delete `RoleCategoryGroups`

**File:** `app/services/role_category_groups.rb` — delete. Zero references anywhere in the codebase.

### Note #8 — Gate daily AI credits behind Flipper flag

**File:** `app/interactors/reset_daily_ai_credits.rb`

Add `return unless Flipper.enabled?(:AI_DAILY_CREDITS, organization)` after the `allocation.nil? || allocation.zero?` guard. Pattern: parallel to the `:AI_APPLICANT_SUMMARY` check in `ValidateAiSummaryGeneration`.

### Note #9A — New controllers, renamed policies, consolidated hooks

#### Delete

- `app/controllers/api/v1/ai_credits_controller.rb`
- `app/controllers/api/v1/ai_credit_subscriptions_controller.rb`
- `app/javascript/shared/queryHooks/useAiCreditSubscription.ts`
- `app/javascript/shared/queryHooks/useSubscribeToAiCreditPack.ts`
- `app/javascript/shared/queryHooks/usePurchaseAiCreditTopUp.ts`
- `app/javascript/shared/queryHooks/useCancelAiCreditSubscription.ts`

#### Create `app/controllers/api/v1/organization_ai_credit_balance_controller.rb`

Actions: `show` only. Uses `render_one` with `Api::V1::OrganizationAiCreditBalanceSerializer`. Authorizes via `OrganizationAiCreditBalancePolicy#show?`.

#### Create `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`

Actions: `show`, `checkout` (renamed from `subscribe`), `purchase_top_up`, `cancel`, `prices`.

`show`: uses `render_one` (no envelope wrapper). Returns the serialized `OrganizationAiCreditPurchase` object directly, or `null` when no active subscription.

`checkout` (renamed from `subscribe`): authorizes via `BillingPolicy#create_subscription?`. Validates `OrganizationAiCreditPurchase.subscription_key?`. Creates checkout session. Immediately creates `OrganizationAiCreditPurchase` record per Note #9B-5. Params key: `:organization_ai_credit_purchase`.

`purchase_top_up`: authorizes via `BillingPolicy#checkout?`. Validates `OrganizationAiCreditPurchase.one_off_key?`. Adds `invoice_creation` per Note #4. Params key: `:organization_ai_credit_purchase`.

`cancel`: mirrors current `#cancel`.

`prices` (new per Note #9B-2): `Stripe::Price.list(lookup_keys: <four pack keys>, active: true, expand: ['data.product'])` → render raw filtered Stripe list. Authorizes via `OrganizationAiCreditPurchasePolicy#show?`.

#### Rename policies

- `app/policies/ai_credit_policy.rb` → `app/policies/organization_ai_credit_balance_policy.rb`, rename class to `OrganizationAiCreditBalancePolicy`. `show?` stays `is_org_user?`.
- `app/policies/ai_credit_subscription_policy.rb` → `app/policies/organization_ai_credit_purchase_policy.rb`, rename class to `OrganizationAiCreditPurchasePolicy`. `show?` stays `is_org_user?`.

#### Routes (`config/routes.rb`)

Replace the existing AI credit routes:

```ruby
# NEW:
resource :ai_credits, only: [:show], controller: 'organization_ai_credit_balance'
resource :ai_credit_purchases, only: [:show], controller: 'organization_ai_credit_purchases' do
  collection do
    post :checkout
    post :purchase_top_up
    put :cancel
    get :prices
  end
end
```

#### Create `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`

Contains all four hooks:
- `useOrganizationAiCreditPurchase` (GET `/ai_credit_purchases`) — replaces `useAiCreditSubscription`. Response shape is the direct serialized object or `null`. Query key: `["organizationAiCreditPurchase"]`.
- `useCheckoutAiCreditPack` (POST `/ai_credit_purchases/checkout`) — replaces `useSubscribeToAiCreditPack`. Variables key: `{ organizationAiCreditPurchase: { stripePriceLookupKey } }`.
- `usePurchaseAiCreditTopUp` (POST `/ai_credit_purchases/purchase_top_up`) — replaces old hook. Variables key: `{ organizationAiCreditPurchase: { stripePriceLookupKey } }`.
- `useCancelAiCreditSubscription` (PUT `/ai_credit_purchases/cancel`) — same behavior, updated path.

Also add `useOrganizationAiCreditPurchasePrices` (GET `/ai_credit_purchases/prices`) in the same file.

`useOrganizationAiCreditBalance.ts` stays standalone, path `/ai_credits` unchanged.

#### Update `AccountBillingAiCredits.tsx`

- Replace all four old hook imports with imports from `useOrganizationAiCreditPurchase`.
- Remove the `subscriptionData?.aiCreditSubscription` unwrap — the new `#show` returns the object directly.
- Remove hardcoded `SUBSCRIPTION_TIERS` and `TOP_UP_TIERS` arrays.
- Add `useOrganizationAiCreditPurchasePrices` hook call. Use `aiCreditPrices(pricesData)` from `planHelpers.ts` to transform raw prices.

### Note #9B-1 — Correct credit pack identifiers

**File:** `app/models/organization_ai_credit_purchase.rb` (`CREDIT_PACKS_BY_LOOKUP_KEY` constant)

Replace the six fabricated packs with the four real packs:

```ruby
CREDIT_PACKS_BY_LOOKUP_KEY = {
  'ai_credit_pack_top_up_small' => { kind: :one_off, credits: 100, name: 'Credit Pack Top-Up — Small' },
  'ai_credit_pack_top_up_large' => { kind: :one_off, credits: 1000, name: 'Credit Pack Top-Up — Large' },
  'ai_credit_pack_subscription_small_monthly' => { kind: :subscription, credits_per_period: 500, name: 'Credit Pack Subscription — Small Monthly' },
  'ai_credit_pack_subscription_large_monthly' => { kind: :subscription, credits_per_period: 2000, name: 'Credit Pack Subscription — Large Monthly' }
}.freeze
```

**Specs to update with new pack keys:**
- `spec/models/organization_ai_credit_purchase_spec.rb`
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`
- `spec/interactors/apply_ai_credit_purchase_spec.rb`
- `spec/interactors/apply_ai_credit_refund_spec.rb`
- `spec/interactors/cancel_ai_credit_subscription_spec.rb`

Delete `spec/initializers/ai_credit_packs_spec.rb`; migrate coverage to `spec/models/organization_ai_credit_purchase_spec.rb`.

### Note #9B-2 — Fetch pack prices from Stripe; transform via `planHelpers`

**File:** `app/javascript/shared/lib/planHelpers.ts`

Add two exports at the end of the existing file:

```ts
export const AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY: { [lookupKey: string]: number } = {
  ai_credit_pack_top_up_small: 100,
  ai_credit_pack_top_up_large: 1000,
  ai_credit_pack_subscription_small_monthly: 500,
  ai_credit_pack_subscription_large_monthly: 2000,
};

export const aiCreditPrices = (stripePrices: any[]) => {
  const prices = [];

  Object.keys(AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY).forEach((lookupKey) => {
    const price = stripePrices.find((p) => p.lookupKey === lookupKey);
    if (!price) return;

    prices.push({
      lookupKey,
      kind: price.type === "recurring" ? "subscription" : "one_off",
      credits: AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY[lookupKey],
      priceId: price.id,
      priceDollars: price.unitAmount / 100,
      currency: price.currency,
      interval: price.recurring ? price.recurring.interval : null,
    });
  });

  return prices;
};
```

### Note #9B-5 — Record credit-pack subscription at checkout

**File:** `OrganizationAiCreditPurchasesController#checkout`

After creating the Stripe checkout session, immediately create the `OrganizationAiCreditPurchase` row with `kind: :subscription`, `stripe_checkout_session_id`, `stripe_price_lookup_key`, and `subscription_credits_per_period`. Leave `subscription_status` nil.

**File:** `app/models/organization_ai_credit_purchase.rb`

Relax validations for pre-checkout state (subscription records created at checkout have no payment data yet):

```ruby
validates :stripe_subscription_id,
          presence: true,
          if: -> { subscription? && stripe_checkout_session_id.blank? }
validates :subscription_current_period_start,
          :subscription_current_period_end,
          presence: true,
          if: -> { subscription? && stripe_subscription_id.present? }
validates :amount_cents_paid,
          presence: true, numericality: { greater_than_or_equal_to: 0 },
          unless: -> { subscription? && stripe_subscription_id.blank? }
validates :currency,
          presence: true,
          unless: -> { subscription? && stripe_subscription_id.blank? }
```

Note: `amount_cents_paid` and `currency` are currently unconditionally required (lines 15-16). At checkout time no payment has been collected, so these fields are unknown. The relaxation defers their requirement until after the subscription is linked via `checkout.session.completed`. They will be populated when `invoice.paid` arrives (see below).

**File:** `app/jobs/stripe_webhook_handler_job.rb`

In `checkout.session.completed` handler, add branch for AI credit subscription: when `object.metadata&.[]('ai_credit_pack_subscription') == 'true'`, find the purchase by `stripe_checkout_session_id` and set `stripe_subscription_id` from `object.subscription`. Place before the existing base-plan block. Use `return` to prevent base-plan handling.

In `handle_credit_pack_invoice_paid`, add `amount_cents_paid` and `currency` to the `existing.update(...)` call: `amount_cents_paid: invoice.amount_paid, currency: invoice.currency`. These fields are nil on checkout-created purchases; they must be populated on the first `invoice.paid`. On renewals they will be overwritten with the latest invoice values, which is fine.

**File:** `app/interactors/apply_ai_credit_purchase.rb`

In `apply_subscription`: remove record-creation logic. The purchase row already exists. If no existing purchase is found, fail with `:missing_purchase`. The `else` branch is removed.

### Note #12 — Rename `ConsumeAiCredits` to `CreateAiCreditBalanceTransaction`

- `app/interactors/consume_ai_credits.rb` → `app/interactors/create_ai_credit_balance_transaction.rb`, rename class
- `app/models/textract_result.rb` — update call site
- `app/interactors/notify_zero_ai_credits.rb` — update comment reference
- `spec/interactors/consume_ai_credits_spec.rb` → `spec/interactors/create_ai_credit_balance_transaction_spec.rb`
- `spec/interactors/credit_consumption_with_notifications_spec.rb` — 3 call sites + comment
- Internal logger strings (2 occurrences)

### Note #25 — Fix dead `retry_on` in `BulkGenerateAiSummariesJob`

**File:** `app/jobs/bulk_generate_ai_summaries_job.rb`

Swap declaration order: `discard_on StandardError` first, `retry_on CustomErrorAiSummary` second. This makes `retry_on` the first handler checked, giving provider/connection errors 3 attempts.

**TDD requirement:** Spec must be written and must FAIL before the declaration swap. No modifications to the spec after the code change.

### Note #13 — Add email notification on bulk AI summary completion

#### New file: `app/mailers/bulk_job_application_ai_summary_result_mailer.rb`

Pattern: `app/mailers/job_resume_export_mailer.rb`. Args by ID.

Two methods:
- `complete(user_id, job_id, succeeded_count, failed_count, skipped_count, hiring_stage_id)` — template `user-bulk-ai-summary-complete`, subject `"Your AI summaries for #{job_title} are ready"`
- `failed(user_id, job_id, total_queued_count)` — template `user-bulk-ai-summary-failed`, subject `"We couldn't generate AI summaries for #{job_title}"`

**File:** `app/jobs/bulk_generate_ai_summaries_job.rb`

Add `notify_complete` and `notify_failure` private methods. Refactor `on_complete` to a clean branch: if succeeded == 0 AND failed > 0, call `notify_failure`; otherwise call `notify_complete`. Update `discard_on` and `retry_on` exhaustion blocks to call `notify_failure`.

Per known failure pattern #4: every mailer call must chain `.deliver_later`.

**File:** `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts` — add `AiSummaryBulkFailedPayload`

**File:** `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` — add handler for `AI_SUMMARY_BULK_FAILED`

### Note #19 — Create `lib/tasks/AI_TASKS_README.md`

New file documenting AI rake tasks. Two sections: "Recurring tasks (Heroku Scheduler)" (four tasks) and "On-demand / manual tasks" (five tasks). Content as specified in approved decisions.

### Note #26 — Remove `prompt_text` from `AiJobApplicationSummary`

Migration edit covered in Data Model Changes section.

**File:** `app/services/ai_job_application_action/summary/generate.rb` — remove `prompt_text` from `extraction_update_params` and `succeeded_update_params`

**File:** `lib/tasks/ai_bulk_extract.rake` — remove `prompt_text:` from the `summary.update(...)` call

### Note #27 — Remove redundant overdue check chain

**File:** `app/models/organization_ai_credit_balance.rb` — remove `OVERDUE_RESET_GRACE`, `period_overdue?`, `reset_ai_credits_if_overdue`

**File:** `app/models/organization.rb` — rename `process_overdue_ai_credit_resets` to `process_ai_credit_resets`. Replace call to `reset_ai_credits_if_overdue` with `org.organization_ai_credit_balance.reset_ai_credits`. Keep `6.hours.ago` in the scope query directly (grace period moves from model method into scope).

**File:** `lib/tasks/ai_credits.rake` — `Organization.process_overdue_ai_credit_resets` → `Organization.process_ai_credit_resets`

### Note #30 — `create_ai_credit_state_if_needed` silent failure

**File:** `app/models/organization.rb` — add `Sentry.capture_exception(e)` to the rescue block. Keep existing `Rails.logger.error` and `ap`. No re-raise.

### Note #31 — `PlanFeatureGate` unknown-plan fallback asymmetry

**File:** `config/initializers/01_variables.rb` — add `AI_DAILY_CREDIT_ALLOCATION = ENV['AI_DAILY_CREDIT_ALLOCATION']&.to_i || 5`

**File:** `app/services/plan_feature_gate.rb` — change `DAILY_AI_CREDIT_ALLOCATION = 5` to `DAILY_AI_CREDIT_ALLOCATION = Variables::AI_DAILY_CREDIT_ALLOCATION`. Fix `daily_ai_credit_allocation` method fallback to `|| DAILY_AI_CREDIT_ALLOCATION`.

### Note #34 — Rename `AI_CREDITS_EXHAUSTED` WebSocket action

**File:** `app/models/textract_result.rb` — rename `broadcast_credits_exhausted` to `broadcast_ai_summary_failed`. Change action from `'AI_CREDITS_EXHAUSTED'` to `'AI_SUMMARY_FAILED'`. Add `errorMessage` to payload from the validation error string.

**File:** `app/interactors/validate_ai_summary_generation.rb` — line ~29: `'Resume processing has failed. Try uploading a different file.'` → `'Resume processing has failed. Try uploading a different resume file.'`

**File:** `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` — rename case to `"AI_SUMMARY_FAILED"`, use `payload.errorMessage` in toast

**File:** `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts` — rename `AiCreditsExhaustedPayload` to `AiSummaryFailedPayload`, add `errorMessage: string`

### Note #35 — Remove redundant `saved_change_to_id?` check

**File:** `app/models/textract_result.rb` — line ~97: remove `|| saved_change_to_id?`

### Note #37 — Remove misleading comment in `plan_feature_gate.rb`

**File:** `app/services/plan_feature_gate.rb` — remove line 76 comment: `# Universal features available to all tier 1 and tier 2 paid plans`

---

## Frontend Changes: Plato AI Tab Consolidation (Note #16)

### New file: `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AccountPlatoAiContainer.tsx`

Pattern: `AccountIntegrationsContainer.tsx` — two-column layout with internal sidebar (NavItems) and content area (Switch/Route). Admin-only gate via `useAuthorization`.

Internal sidebar order:
1. Settings (default landing)
2. Billing
3. Usage

Default redirect: `<Redirect to={match.url}/settings} />`

Styled components match `AccountIntegrationsContainer` exactly: `Styled.Container` (flex, height 100%), `Styled.Sidebar` (40vw / 33.333% at lg, border-right), `Styled.Content` (66.666%, overflow-y auto).

### Modify `AccountContainer.tsx`

1. Remove imports for `OrganizationAiSettings`, `OrganizationAiBilling`, `OrganizationAiUsage`.
2. Add import for `AccountPlatoAiContainer`.
3. In `adminOrgPathNames`: replace the three AI entries with one `"/hire/settings/plato-ai": "Plato AI"` entry.
4. In `memberPathNames`: remove `"/hire/settings/ai-usage": "AI usage"`. Non-admins get no Plato AI tab.
5. In the `<Switch>`: remove the three separate AI routes. Add one route for `/hire/settings/plato-ai` with `exact={false}`, rendering `AccountPlatoAiContainer`.

---

## Authorization Requirements

| Resource | Policy class (after rename) | `show?` | Other actions |
|---|---|---|---|
| `OrganizationAiCreditBalance` | `OrganizationAiCreditBalancePolicy` | `is_org_user?` | — |
| `OrganizationAiCreditPurchase` | `OrganizationAiCreditPurchasePolicy` | `is_org_user?` | `checkout`, `purchase_top_up`, `cancel` use `BillingPolicy` |
| `AccountPlatoAiContainer` | `useAuthorization({ adminOnly: true })` | admin only | — |

Non-admins get no Plato AI tab at all.

---

## Constraints and Requirements

### Stripe consistency (Notes #4, #9B-5)
- `purchase_top_up` must set `invoice_creation.enabled: true` so Stripe creates an invoice. Credit grant fires on `invoice.paid`, not `checkout.session.completed`.
- Credit pack subscription checkout creates the `OrganizationAiCreditPurchase` row immediately. The row is pre-active until `checkout.session.completed` sets `stripe_subscription_id` and `invoice.paid` sets status/period/ledger.
- `OrganizationAiCreditPurchase` validation relaxation required: subscription records may be created without `stripe_subscription_id`, `amount_cents_paid`, or `currency`.
- The `else` branch in `handle_credit_pack_invoice_paid` that creates purchase records via `ApplyAiCreditPurchase.call` is removed. If no existing purchase found, fail rather than create.
- `handle_credit_pack_invoice_paid` must populate `amount_cents_paid` and `currency` on the purchase (set from the invoice on first `invoice.paid`).

### Enum rename (Note #5)
- Both column name and values change. Migration must be rolled back and re-run (dev-only).
- All ripple sites must be updated atomically.

### Hook consolidation (Note #9A)
- `useAiCreditSubscription` returns `{ aiCreditSubscription: ... }` (wrapped). The new hook unwraps to direct object or `null`. Every consumer must be updated before old hook is deleted.
- Query key changes from `["aiCreditSubscription"]` to `["organizationAiCreditPurchase"]`.
- Params key changes from `{ aiCreditSubscription: ... }` to `{ organizationAiCreditPurchase: ... }`.

### BulkGenerateAiSummariesJob retry/discard order (Note #25)
- Spec MUST fail before the declaration swap. The fix alone must make it pass.
- Both `discard_on` and `retry_on` exhaustion blocks need `notify_failure`.

### Mailer pattern (Notes #1, #13)
- Per known failure pattern #4: every mailer call must chain `.deliver_later`.

### AccountPlatoAiContainer routing
- Route `exact={false}` on `/hire/settings/plato-ai` so sub-paths are matched.
- Old routes (`/hire/settings/ai`, `/hire/settings/ai-billing`, `/hire/settings/ai-usage`) are removed. No redirect needed — dev-only paths.

---

## Existing Patterns to Follow

| Pattern | File to follow |
|---|---|
| Two-column container with internal NavItems + Switch/Redirect | `app/javascript/ats/src/views/accountAdmin/accountIntegrations/AccountIntegrationsContainer.tsx` |
| Mailer with ID-based args and `Emails::SendTemplateEmail` | `app/mailers/job_resume_export_mailer.rb` |
| Controller with `render_one` (no envelope) | `app/controllers/api/v1/ai_credits_controller.rb` (current `show`) |
| Stripe `invoice_creation` pattern | `app/controllers/api/v1/board_wwr_listings_controller.rb` lines 101–110 |
| Checkout session recording at controller time | `app/controllers/api/v1/billing_controller.rb` line 113 |
| Stripe subscription ID linking in `checkout.session.completed` | `app/jobs/stripe_webhook_handler_job.rb` lines 67–73 |
| Flipper guard in interactor | `app/interactors/validate_ai_summary_generation.rb` |
| React Query consolidated hook file | `app/javascript/shared/queryHooks/useOrganizationAiCreditBalance.ts` |
| `planHelpers.ts` additions | Append to end of existing file |
| Sentry capture in rescue | `app/models/organization.rb` `handle_before_update` rescue block |

---

## Test Requirements

### New: `spec/mailers/ai_credit_notification_mailer_spec.rb`

First mailer spec in the repo. Stubs `Emails::SendTemplateEmail`.

Required assertions:
- `admin_recipients` returns User records for `org_admin`, `org_owner`, `god_admin`; excludes `org_user` and `org_interviewer`
- `low_credits` message_params: correct `to`, `subject`, `template` (`'user-ai-credit-balance-low'`), `variables` including `credits_remaining`
- `zero_credits` message_params: correct `to`, `subject`, `template` (`'user-ai-credit-balance-zero'`)
- `Emails::SendTemplateEmail#send` invoked once per recipient

Add `create_credit_test_organization_user(organization, role:)` helper to `spec/support/ai_credits_test_helpers.rb`.

### New: `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`

TDD — must fail before declaration swap (Note #25).

Required assertions:
- `CustomErrorAiSummary` during `each_iteration` → retried, not discarded
- Non-`CustomErrorAiSummary` `StandardError` → discarded, not retried
- `on_complete` with succeeded > 0 → `AI_SUMMARY_BULK_COMPLETE` broadcast + `complete` mailer `.deliver_later`
- `on_complete` with succeeded == 0 && failed > 0 → `AI_SUMMARY_BULK_FAILED` broadcast + `failed` mailer `.deliver_later`

Per failure pattern #4: stub mailer methods to return `instance_double(ActionMailer::MessageDelivery)` and verify `.deliver_later` is called.

### Renamed: `spec/interactors/consume_ai_credits_spec.rb` → `spec/interactors/create_ai_credit_balance_transaction_spec.rb`

Update class reference. No new coverage needed.

### Updated: `spec/interactors/credit_consumption_with_notifications_spec.rb`

Update 3 call sites + comment from `ConsumeAiCredits` to `CreateAiCreditBalanceTransaction`.

### Migrated: `spec/initializers/ai_credit_packs_spec.rb` → deleted

Coverage moves to `spec/models/organization_ai_credit_purchase_spec.rb` — add `describe 'CREDIT_PACKS_BY_LOOKUP_KEY'` block covering four real packs.

### Updated: `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`

- Update lookup keys to four real packs
- Add test for `checkout.session.completed` with `ai_credit_pack_subscription: 'true'` metadata → links purchase
- Remove test for `checkout.session.completed` with `mode: 'payment'`
- Add test for `invoice.paid` with `ai_credit_pack_top_up: 'true'` metadata → grants one-off credits

### Updated: `spec/interactors/apply_ai_credit_purchase_spec.rb`

- Update lookup keys to four real packs
- Remove subscription creation tests
- Add test: existing purchase found → grants credits
- Add test: no existing purchase → fails with `:missing_purchase`

### Updated: `spec/interactors/apply_ai_credit_refund_spec.rb`

Update lookup keys to four real packs.

### Updated: `spec/interactors/cancel_ai_credit_subscription_spec.rb`

Update lookup keys to four real packs.

### Renamed: `spec/policies/ai_credit_policy_spec.rb` → `spec/policies/organization_ai_credit_balance_policy_spec.rb`

Rename file and class reference.

---

## API Changes

| Method | Old path | New path | Notes |
|---|---|---|---|
| GET | `/ai_credits` | `/ai_credits` | Unchanged path; new controller |
| GET | `/ai_credit_subscriptions` | `/ai_credit_purchases` | Response shape changes: direct object, no wrapper |
| POST | `/ai_credit_subscriptions/subscribe` | `/ai_credit_purchases/checkout` | Action renamed; params key changes |
| POST | `/ai_credits/purchase_top_up` | `/ai_credit_purchases/purchase_top_up` | Moves to new controller |
| PUT | `/ai_credit_subscriptions/cancel` | `/ai_credit_purchases/cancel` | Moves to new controller |
| GET | — | `/ai_credit_purchases/prices` | New: returns raw Stripe price list |
