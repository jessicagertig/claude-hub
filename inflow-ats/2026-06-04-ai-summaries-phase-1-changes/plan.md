# Implementation Plan — AI Summaries Phase 1 Changes

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Spec:** `SPEC.md` in this directory
**Date:** 2026-06-04

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

---

## Summary

This plan covers ~30 changes to the AI summaries and AI credits system: bug fixes (mailer `NoMethodError`, Stripe webhook misrouting, dead `retry_on`), model/enum renames, controller restructuring from two controllers to two new model-aligned controllers, Stripe checkout hardening (two-step subscription handshake, top-up invoice creation), service refactors, dead-code removal, a new bulk-job email notification system, and a frontend navigation consolidation (three AI sidebar tabs into one "Plato AI" container). No new database migrations are created — existing dev-only migrations are edited in place and re-run.

---

## Pattern Precedents

| Pattern | Existing file |
|---|---|
| Mailer with ID-based args and `Emails::SendTemplateEmail` | `app/mailers/job_resume_export_mailer.rb` |
| Controller with `render_one` (no envelope) | `app/controllers/api/v1/ai_credits_controller.rb` `#show` |
| Stripe `invoice_creation` on checkout session | `app/controllers/api/v1/board_wwr_listings_controller.rb` `Stripe::Checkout::Session.create` call |
| Recording checkout session ID at controller time | `app/controllers/api/v1/billing_controller.rb` — `current_organization.update(stripe_checkout_session_id: session.id)` |
| Linking Stripe subscription ID in `checkout.session.completed` | `app/jobs/stripe_webhook_handler_job.rb` `checkout.session.completed` handler — `organization.update(stripe_subscription_id: object.subscription)` |
| Flipper guard in interactor | `app/interactors/validate_ai_summary_generation.rb` — `Flipper.enabled?(:AI_APPLICANT_SUMMARY, @organization)` |
| Two-column container with internal NavItems + Switch/Redirect | `app/javascript/ats/src/views/accountAdmin/accountIntegrations/AccountIntegrationsContainer.tsx` |
| React Query consolidated hook file | `app/javascript/shared/queryHooks/useOrganizationAiCreditBalance.ts` |
| React Query mutation hook with invalidation | `app/javascript/shared/queryHooks/useSubscribeToAiCreditPack.ts` |
| Interactor with `fail_with_record_invalid` helper | `app/interactors/apply_ai_credit_refund.rb` |
| Sentry capture in rescue | `app/models/organization.rb` `create_ai_credit_state_if_needed` rescue block (adding Sentry to it) |
| Test helpers module | `spec/support/ai_credits_test_helpers.rb` |
| `planHelpers.ts` additions | Append to end of existing file |

---

## Implementation Sequence

### Phase A — TDD: Write Failing Spec for `retry_on` Bug (Note #25)

**Why first:** The TDD requirement is non-negotiable. The spec must fail against current code BEFORE the declaration swap. Writing this spec first establishes the failing baseline.

**cursor_rules to read:** `cursor_rules/backend_base.md`, `cursor_rules/core_critical_rules.md`

- [ ] **A.1** Add two new `describe` blocks to `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`. The spec already exists with `#each_iteration` and `#on_complete` blocks. Add the retry/discard assertions as new top-level `describe` blocks:
  - [ ] **A.1.1** `CustomErrorAiSummary` during `each_iteration` results in retry (re-enqueue), not discard
  - [ ] **A.1.2** Non-`CustomErrorAiSummary` `StandardError` results in discard, not retry
- [ ] **A.2** Run spec. Confirm it FAILS. Record the failure output for the commit message. Do not fix the code yet.

---

### Phase B — Migration Edits and Rollback Sequence

**Why second:** Column renames and schema changes must be in place before model code references the new names. These are in-place edits to dev-only migrations.

**cursor_rules to read:** `cursor_rules/backend_base.md`

- [ ] **B.1** Check current migration status with `bundle exec rails db:migrate:status`
- [ ] **B.2** Roll back to before `20260408040701` (the `auto_generate_ai_summaries_setting` migration). This also rolls back the data migration `20260408040802`.
- [ ] **B.3** Edit `db/migrate/20260408040701_add_auto_generate_ai_summaries_setting_to_jobs.rb`:
  - [ ] **B.3.1** Rename the file to `20260408040701_add_auto_generate_ai_summaries_to_jobs.rb`
  - [ ] **B.3.2** Rename class to `AddAutoGenerateAiSummariesToJobs`
  - [ ] **B.3.3** Change column name from `auto_generate_ai_summaries_setting` to `auto_generate_ai_summaries`
- [ ] **B.4** Roll back to before `20260311120000` (the `create_ai_job_application_summaries` migration)
- [ ] **B.5** Edit `db/migrate/20260311120000_create_ai_job_application_summaries.rb`:
  - [ ] **B.5.1** Remove `t.text :prompt_text`
- [ ] **B.6** Edit `db/data/20260408040802_add_ai_settings_to_existing_organizations.rb`:
  - [ ] **B.6.1** Change `default_auto_generate_ai_summaries_enabled:` to `auto_generate_ai_summaries_enabled:` in the `AI_SETTING_DEFAULTS` hash
- [ ] **B.7** Re-migrate: `bundle exec rails db:migrate`
- [ ] **B.8** Verify with `bundle exec rails db:migrate:status`

**Note:** Rolling back `20260311120000` will drop `ai_job_application_summaries` and `ai_api_requests` tables. Any local test data in those tables will be lost. This is acceptable for a dev-only feature.

---

### Phase C — Model and Service Changes (No Dependencies on Controllers)

**Why third:** These establish the renamed identifiers, new constants, and fixed methods that controllers and frontend will depend on.

**cursor_rules to read:** `cursor_rules/core_critical_rules.md`, `cursor_rules/backend_base.md`

- [ ] **C.1** Move `AiCreditPacks` into `OrganizationAiCreditPurchase` (Note #6A). Modify `app/models/organization_ai_credit_purchase.rb`:
  - [ ] **C.1.1** Add `CREDIT_PACKS_BY_LOOKUP_KEY` frozen hash with the four real packs (Note #9B-1):
    - `ai_credit_pack_top_up_small` — one_off, 100 credits
    - `ai_credit_pack_top_up_large` — one_off, 1000 credits
    - `ai_credit_pack_subscription_small_monthly` — subscription, 500 credits_per_period
    - `ai_credit_pack_subscription_large_monthly` — subscription, 2000 credits_per_period
  - [ ] **C.1.2** Add class methods: `registered_keys`, `lookup_by_key`, `subscription_key?`, `one_off_key?`, `credit_amount_for_key` (copied from the initializer)
  - [ ] **C.1.3** Update the validation on `stripe_price_lookup_key` from `AiCreditPacks.registered_keys` to `OrganizationAiCreditPurchase.registered_keys`
  - [ ] **C.1.4** Relax validations for pre-checkout state (Note #9B-5):
    - `stripe_subscription_id`: presence only if subscription AND `stripe_checkout_session_id.blank?`
    - `subscription_current_period_start`, `subscription_current_period_end`: presence only if subscription AND `stripe_subscription_id.present?`
    - `amount_cents_paid`: presence + numericality unless subscription with blank `stripe_subscription_id`
    - `currency`: presence unless subscription with blank `stripe_subscription_id`
  - [ ] **C.1.5** Delete `config/initializers/ai_credit_packs.rb`
- [ ] **C.2** Delete `app/services/role_category_groups.rb` (Note #6B). Zero references anywhere.

- [ ] **C.3** Rename `auto_generate_ai_summaries_setting` enum and cascade method (Note #5):
  - [ ] **C.3.1** `app/models/job.rb`: rename enum `auto_generate_ai_summaries_setting` to `auto_generate_ai_summaries`; rename values: `inherit` to `default` (0), `on` to `enabled` (1), `off` to `disabled` (2); keep `_prefix: true`
  - [ ] **C.3.2** `app/models/job.rb`: rename `effective_auto_generate_ai_summaries_enabled?` to `should_auto_generate_ai_summaries?`; update body predicates from `auto_generate_ai_summaries_setting_on?` to `auto_generate_ai_summaries_enabled?`, `auto_generate_ai_summaries_setting_off?` to `auto_generate_ai_summaries_disabled?`, and org call from `organization.default_auto_generate_ai_summaries_enabled?` to `organization.auto_generate_ai_summaries_enabled`
  - [ ] **C.3.3** `app/serializers/api/v1/job_serializer.rb`: rename `:auto_generate_ai_summaries_setting` to `:auto_generate_ai_summaries`
  - [ ] **C.3.4** `app/controllers/api/v1/jobs_controller.rb`: strong params — rename `:auto_generate_ai_summaries_setting` to `:auto_generate_ai_summaries`; rename `job_params.key?(:auto_generate_ai_summaries_setting)` to `job_params.key?(:auto_generate_ai_summaries)`
  - [ ] **C.3.5** `app/models/organization.rb`: rename `default_auto_generate_ai_summaries_enabled?` to `auto_generate_ai_summaries_enabled` (no `?`); update body: rename `settings&.dig('default_auto_generate_ai_summaries_enabled')` to `settings&.dig('auto_generate_ai_summaries_enabled')`
  - [ ] **C.3.6** `app/controllers/api/v1/organizations_controller.rb`: permitted settings param — rename `:default_auto_generate_ai_summaries_enabled` to `:auto_generate_ai_summaries_enabled`
  - [ ] **C.3.7** `app/models/textract_result.rb`: rename `effective_auto_generate_ai_summaries_enabled?` to `should_auto_generate_ai_summaries?`
- [ ] **C.4** Rename `ConsumeAiCredits` to `CreateAiCreditBalanceTransaction` (Note #12):
  - [ ] **C.4.1** Rename `app/interactors/consume_ai_credits.rb` to `app/interactors/create_ai_credit_balance_transaction.rb`; rename class
  - [ ] **C.4.2** `app/models/textract_result.rb`: rename `ConsumeAiCredits.call` to `CreateAiCreditBalanceTransaction.call`
  - [ ] **C.4.3** `app/interactors/notify_zero_ai_credits.rb`: update comment reference
  - [ ] **C.4.4** Internal logger strings in the renamed interactor (2 occurrences of `ConsumeAiCredits`)
- [ ] **C.5** Fix `ApplyAiCreditRefund` bugs (Notes #3, #32). In `app/interactors/apply_ai_credit_refund.rb`:
  - [ ] **C.5.1** Change `.order(:created_at).first` to `.order(:created_at).last` on `original_credit_row`
  - [ ] **C.5.2** Remove `.reload` on `purchase.organization.organization_ai_credit_balance` (use the chain directly)
  - [ ] **C.5.3** Remove `.reload`: change `context.purchase = purchase.reload` to `context.purchase = purchase`
- [ ] **C.6** Remove `prompt_text` from service and rake (Note #26):
  - [ ] **C.6.1** `app/services/ai_job_application_action/summary/generate.rb`: remove `prompt_text: extraction_messages.to_json` from `extraction_update_params` hash
  - [ ] **C.6.2** `app/services/ai_job_application_action/summary/generate.rb`: remove the `prompt_text: { ... }.compact.to_json` entry from `succeeded_update_params` hash
  - [ ] **C.6.3** `lib/tasks/ai_bulk_extract.rake`: remove `prompt_text:` from the `summary.update(...)` call at line 62. Do NOT remove the `prompt_text:` at line 78 — that is inside `AiApiRequest.create`, which keeps its own `prompt_text` column
- [ ] **C.7** Remove redundant overdue check chain (Note #27):
  - [ ] **C.7.1** `app/models/organization_ai_credit_balance.rb`: remove `OVERDUE_RESET_GRACE` constant
  - [ ] **C.7.2** `app/models/organization_ai_credit_balance.rb`: remove `period_overdue?` method
  - [ ] **C.7.3** `app/models/organization_ai_credit_balance.rb`: remove `reset_ai_credits_if_overdue` method
  - [ ] **C.7.4** `app/models/organization_ai_credit_balance.rb`: remove `apply_top_up_checkout` method (dead code per Note #4 — its sole caller in `checkout.session.completed` `mode == 'payment'` branch is being removed)
  - [ ] **C.7.5** `app/models/organization.rb`: rename `process_overdue_ai_credit_resets` to `process_ai_credit_resets`
  - [ ] **C.7.6** `app/models/organization.rb`: replace `org.organization_ai_credit_balance.reset_ai_credits_if_overdue` with `org.organization_ai_credit_balance.reset_ai_credits`
  - [ ] **C.7.7** `app/models/organization.rb`: update error log string from `process_overdue_ai_credit_resets` to `process_ai_credit_resets`
  - [ ] **C.7.8** `lib/tasks/ai_credits.rake`: rename `Organization.process_overdue_ai_credit_resets` to `Organization.process_ai_credit_resets`
- [ ] **C.8** Fix `is_admin?` mailer bug + rename templates (Notes #1, #20, #38). In `app/mailers/ai_credit_notification_mailer.rb`:
  - [ ] **C.8.1** Change `select(&:is_admin?)` to `select(&:is_admin)` in `admin_recipients`
  - [ ] **C.8.2** Rename `'ai-credits-low'` to `'user-ai-credit-balance-low'`
  - [ ] **C.8.3** Rename `'ai-credits-zero'` to `'user-ai-credit-balance-zero'`
  - [ ] **C.8.4** Remove the TODO comment at the top
- [ ] **C.9** Gate daily AI credits behind Flipper flag (Note #8). In `app/interactors/reset_daily_ai_credits.rb`: add `return unless Flipper.enabled?(:AI_DAILY_CREDITS, organization)` after the `allocation.nil? || allocation.zero?` guard (before the `already_reset_today` check)
- [ ] **C.10** `PlanFeatureGate` fallback fix + env var (Notes #31, #37):
  - [ ] **C.10.1** `config/initializers/01_variables.rb`: add `AI_DAILY_CREDIT_ALLOCATION = ENV['AI_DAILY_CREDIT_ALLOCATION']&.to_i || 5`
  - [ ] **C.10.2** `app/services/plan_feature_gate.rb`: change `DAILY_AI_CREDIT_ALLOCATION = 5` to `DAILY_AI_CREDIT_ALLOCATION = Variables::AI_DAILY_CREDIT_ALLOCATION`
  - [ ] **C.10.3** `app/services/plan_feature_gate.rb`: fix `daily_ai_credit_allocation` method — change `plan_rules[@plan]&.dig(:daily_ai_credit_allocation)` to `plan_rules[@plan]&.dig(:daily_ai_credit_allocation) || DAILY_AI_CREDIT_ALLOCATION`
  - [ ] **C.10.4** `app/services/plan_feature_gate.rb`: remove line 76 comment `# Universal features available to all tier 1 and tier 2 paid plans`
- [ ] **C.11** `create_ai_credit_state_if_needed` Sentry capture (Note #30). In `app/models/organization.rb`: add `Sentry.capture_exception(e)` to the rescue block in `create_ai_credit_state_if_needed`, before the existing `Rails.logger.error`
- [ ] **C.12** Remove redundant `saved_change_to_id?` (Note #35). In `app/models/textract_result.rb`: remove `|| saved_change_to_id?` from the guard in `queue_ai_summary_job`
- [ ] **C.13** Rename WebSocket action `AI_CREDITS_EXHAUSTED` to `AI_SUMMARY_FAILED` (Note #34):
  - [ ] **C.13.1** `app/models/textract_result.rb`: rename `broadcast_credits_exhausted` to `broadcast_ai_summary_failed`
  - [ ] **C.13.2** `app/models/textract_result.rb`: change action string from `'AI_CREDITS_EXHAUSTED'` to `'AI_SUMMARY_FAILED'`
  - [ ] **C.13.3** `app/models/textract_result.rb`: add `errorMessage` to the payload — add a `validation_error` parameter to the method. The caller in `queue_ai_summary_job` should pass the `result.error` string from `ValidateAiSummaryGeneration`
  - [ ] **C.13.4** `app/interactors/validate_ai_summary_generation.rb`: change line 29 error string from `'Resume processing has failed. Try uploading a different file.'` to `'Resume processing has failed. Try uploading a different resume file.'`
- [ ] **C.14** Update `AiCreditPacks` references in remaining backend files:
  - [ ] **C.14.1** `app/jobs/stripe_webhook_handler_job.rb`: replace all `AiCreditPacks.*` calls with `OrganizationAiCreditPurchase.*`
  - [ ] **C.14.2** `app/interactors/apply_ai_credit_purchase.rb`: replace `AiCreditPacks.credit_amount_for_key` with `OrganizationAiCreditPurchase.credit_amount_for_key`

---

### Phase D — Controller Restructuring (Notes #9A, #4, #9B-5)

**Why after Phase C:** The new controllers depend on `OrganizationAiCreditPurchase` having the class methods from Phase C.1, the relaxed validations from C.1, and the renamed methods throughout.

**cursor_rules to read:** `cursor_rules/core_critical_rules.md`, `cursor_rules/backend_controllers.md`

- [ ] **D.1** Rename policies:
  - [ ] **D.1.1** Rename `app/policies/ai_credit_policy.rb` to `app/policies/organization_ai_credit_balance_policy.rb`; rename class to `OrganizationAiCreditBalancePolicy`
  - [ ] **D.1.2** Rename `app/policies/ai_credit_subscription_policy.rb` to `app/policies/organization_ai_credit_purchase_policy.rb`; rename class to `OrganizationAiCreditPurchasePolicy`
- [ ] **D.2** Create `app/controllers/api/v1/organization_ai_credit_balance_controller.rb`:
  - `show` only. Authorizes via `OrganizationAiCreditBalancePolicy#show?` using `authorize :organization_ai_credit_balance, :show?`. Uses `render_one` with `Api::V1::OrganizationAiCreditBalanceSerializer`.
  - Pattern: existing `AiCreditsController#show`
- [ ] **D.3** Create `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`:
  - Actions: `show`, `checkout`, `purchase_top_up`, `cancel`, `prices`
  - `show`: authorizes via `OrganizationAiCreditPurchasePolicy#show?` using `authorize :organization_ai_credit_purchase, :show?`. Finds active subscription. Returns `render_one(subscription, ...)` or `render json: nil` (no wrapper).
  - `checkout`: authorizes via `BillingPolicy#create_subscription?`. Validates `OrganizationAiCreditPurchase.subscription_key?`. Creates Stripe checkout session with metadata `ai_credit_pack_subscription: 'true'`. Creates `OrganizationAiCreditPurchase` record immediately with `kind: :subscription`, `stripe_checkout_session_id`, `stripe_price_lookup_key`, `subscription_credits_per_period`. Pattern: `billing_controller.rb` line 113.
  - `purchase_top_up`: authorizes via `BillingPolicy#checkout?`. Validates `OrganizationAiCreditPurchase.one_off_key?`. Adds `invoice_creation: { enabled: true, invoice_data: { metadata: { organization_id: ..., stripe_price_lookup_key: ..., ai_credit_pack_top_up: 'true' } } }`. Pattern: `board_wwr_listings_controller.rb` lines 101-110.
  - `cancel`: mirrors existing `AiCreditSubscriptionsController#cancel`
  - `prices`: authorizes via `OrganizationAiCreditPurchasePolicy#show?`. `Stripe::Price.list(lookup_keys: OrganizationAiCreditPurchase.registered_keys, active: true, expand: ['data.product'])` and render raw list.
  - Params key: `:organization_ai_credit_purchase` (single params method)
- [ ] **D.4** Update `config/routes.rb` — replace the `ai_credits` and `ai_credit_subscriptions` resource blocks with:
  ```ruby
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
- [ ] **D.5** Delete `app/controllers/api/v1/ai_credits_controller.rb` and `app/controllers/api/v1/ai_credit_subscriptions_controller.rb`

---

### Phase E — Stripe Webhook Handler Changes (Notes #4, #9B-5)

**Why after Phase D:** The webhook handler changes depend on the model validation relaxation (Phase C.1) and the controller having created the purchase record at checkout (Phase D.2).

**cursor_rules to read:** `cursor_rules/backend_base.md`

- [ ] **E.1** `app/jobs/stripe_webhook_handler_job.rb`, `checkout.session.completed` handler:
  - [ ] **E.1.1** Remove the `object.mode == 'payment'` top-up branch (lines 58-61). This is dead code after the top-up moves to `invoice.paid`.
  - [ ] **E.1.2** Add a new branch BEFORE the existing base-plan code: when `object.metadata&.[]('ai_credit_pack_subscription') == 'true'`, find the `OrganizationAiCreditPurchase` by `stripe_checkout_session_id: object.id` and set `stripe_subscription_id` from `object.subscription`. Return to prevent base-plan handling.
  - [ ] **E.1.3** Verify all `AiCreditPacks.*` references are replaced with `OrganizationAiCreditPurchase.*` (already addressed in C.14)
- [ ] **E.2** `app/jobs/stripe_webhook_handler_job.rb`, `invoice.paid` handler:
  - [ ] **E.2.1** Add a new branch BEFORE the `raise CustomStripeSubscriptionMissingError` guard: when `object.metadata&.[]('ai_credit_pack_top_up') == 'true'`, look up the organization from `object.metadata['organization_id']`, find the lookup key from `object.metadata['stripe_price_lookup_key']`, and call `ApplyAiCreditPurchase.call(session: object, kind: :one_off)`. Use `return` to skip base-plan handling.
  - [ ] **E.2.2** Move the existing `board_wwr_listing_id` and `board_what_jobs_listing_id` branches ABOVE the `raise CustomStripeSubscriptionMissingError` guard — an org with only a listing purchase and no base plan would have nil `stripe_subscription_id`, causing the guard to raise. These branches already `return` so they skip the guard correctly once moved above it.
  - [ ] **E.2.3** In `handle_credit_pack_invoice_paid`, add `amount_cents_paid: invoice.amount_paid, currency: invoice.currency` to the `existing.update(...)` call
  - [ ] **E.2.4** Remove the `else` branch in `handle_credit_pack_invoice_paid` (the one that calls `ApplyAiCreditPurchase.call(invoice: ..., price: ..., kind: :subscription)`) — purchase records are now created at checkout
  - [ ] **E.2.5** Verify all `AiCreditPacks.*` references are replaced with `OrganizationAiCreditPurchase.*`
- [ ] **E.3** `app/interactors/apply_ai_credit_purchase.rb`:
  - [ ] **E.3.1** In `apply_subscription`: remove the record-creation logic (the `purchase = OrganizationAiCreditPurchase.new(...)` and `purchase.save` block). If no existing purchase found by `stripe_subscription_id`, fail with `:missing_purchase`. Keep the ledger-creation and balance-reset logic for when an existing purchase IS found.
  - [ ] **E.3.2** Replace all `AiCreditPacks.*` references with `OrganizationAiCreditPurchase.*`
- [ ] **E.4** `app/models/organization_ai_credit_balance.rb`: remove `apply_top_up_checkout` method (dead code after `mode == 'payment'` branch removal). If already removed in C.7, verify it's gone.

---

### Phase F — Fix `retry_on` Declaration Order (Note #25)

**Why here:** The failing spec from Phase A now becomes the gatekeeper. Swap the declarations, run the spec, confirm it passes.

- [ ] **F.1** `app/jobs/bulk_generate_ai_summaries_job.rb`: swap declaration order — `discard_on StandardError` first, `retry_on CustomErrorAiSummary` second
- [ ] **F.2** Run `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`. The spec from Phase A must now PASS without any spec modifications.

---

### Phase G — Bulk Job Notifications (Note #13)

**Why after Phase F:** The notification methods are added to `BulkGenerateAiSummariesJob` and reference the now-correct `retry_on`/`discard_on` blocks.

**cursor_rules to read:** `cursor_rules/backend_base.md`

- [ ] **G.1** Create `app/mailers/bulk_job_application_ai_summary_result_mailer.rb`. Pattern: `app/mailers/job_resume_export_mailer.rb`. ID-based args — lookup User and Job inside each method. Both methods use `Emails::SendTemplateEmail` pattern, `from: EMAIL_NOTIFICATIONS_ADDRESS`.
  - [ ] **G.1.1** `complete(user_id, job_id, succeeded_count, failed_count, skipped_count, hiring_stage_id)`: template `'user-bulk-ai-summary-complete'`, subject `"Your AI summaries for #{job.title} are ready"`, variables: `user_first_name`, `job_title`, `succeeded_count`, `failed_count`, `skipped_count`, `hiring_stage_link` (built from `Variables::AtsRootUrl` + `/jobs/#{job.id}/stages/#{hiring_stage_id}/applicants`)
  - [ ] **G.1.2** `failed(user_id, job_id, total_queued_count)`: template `'user-bulk-ai-summary-failed'`, subject `"We couldn't generate AI summaries for #{job.title}"`, variables: `user_first_name`, `job_title`, `total_queued_count`
- [ ] **G.2** Add notification methods to `app/jobs/bulk_generate_ai_summaries_job.rb`:
  - [ ] **G.2.1** Add `notify_complete` private method: broadcasts `AI_SUMMARY_BULK_COMPLETE` via `GlobalChannel.broadcast_to` + calls `BulkJobApplicationAiSummaryResultMailer.complete(...).deliver_later`
  - [ ] **G.2.2** Add `notify_failure` private method: broadcasts `AI_SUMMARY_BULK_FAILED` via `GlobalChannel.broadcast_to` + calls `BulkJobApplicationAiSummaryResultMailer.failed(...).deliver_later`. Computes `total_queued_count` from `payload['job_application_ids'].size + payload['skipped_count']`. Guard with `return unless user`.
  - [ ] **G.2.3** Per known failure pattern #4: every mailer call chains `.deliver_later`
  - [ ] **G.2.4** Refactor `on_complete` to a clean branch: if `succeeded == 0 && failed > 0`, call `notify_failure`; otherwise call `notify_complete`
  - [ ] **G.2.5** Update `discard_on` block: after `update_remaining_statuses_to_failed`, call `notify_failure` (access payload via `current_job.arguments.first`)
  - [ ] **G.2.6** Update `retry_on` exhaustion block: after `update_remaining_statuses_to_failed`, call `notify_failure` (access payload via `current_job.arguments.first`)

---

### Phase H — Frontend Changes

**Why after backend:** All API endpoints and response shapes must be stable before the frontend consumes them.

**cursor_rules to read:** `cursor_rules/frontend_base.md`, `cursor_rules/core_critical_rules.md`

- [ ] **H.1** Type changes:
  - [ ] **H.1.1** `app/javascript/shared/types/aiJobApplicationSummary.ts` (Note #2): in `AiResumeStructuredData` remove `totalYearsExperience`, `relevantYearsExperience`, `jobTitleRoleCategory`; add `totalMonthsExperience: number`; add optional evaluative fields: `roleAnalysis?`, `applicableExperience?`, `gaps?`, `overlapSummary?` as `string`; `monthsByDomain?` as `{ [domain: string]: number }`; `assessment?` and `comparison?` as `any`. In `AiWorkExperience` remove `roleCategory` and `relevantToJobTitle`.
  - [ ] **H.1.2** `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts` (Notes #34, #13): rename `AiCreditsExhaustedPayload` to `AiSummaryFailedPayload`; add `errorMessage: string`. Add `AiSummaryBulkFailedPayload` interface with `jobTitle: string`, `message: string`.
  - [ ] **H.1.3** `app/javascript/shared/types/organization.ts` (Note #5): in `OrganizationSettings` rename `defaultAutoGenerateAiSummariesEnabled?` to `autoGenerateAiSummariesEnabled?`
  - [ ] **H.1.4** `app/javascript/ats/src/lib/newLookups.ts` (Note #5): rename type `AutoGenerateAiSummariesSetting` to `AutoGenerateAiSummaries`; rename array `jobAutoGenerateAiSummariesSettingOptions` to `jobAutoGenerateAiSummariesOptions`; rename values `"inherit"` to `"default"`, `"on"` to `"enabled"`, `"off"` to `"disabled"`; update labels: `"Use organization default"` stays, `"On — auto-generate for every new applicant"` becomes `"Enabled — auto-generate for every new applicant"`, `"Off — only generate on demand"` becomes `"Disabled — only generate on demand"`
  - [ ] **H.1.5** Rename `app/javascript/shared/types/aiCreditSubscription.ts` to `app/javascript/shared/types/organizationAiCreditPurchase.ts`; rename interface `AiCreditSubscription` to `OrganizationAiCreditPurchase`, type `AiCreditSubscriptionStatus` to `OrganizationAiCreditPurchaseStatus`

- [ ] **H.2** Query hooks consolidation (Note #9A). Create `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`:
  - [ ] **H.2.1** `useOrganizationAiCreditPurchase` — GET `/ai_credit_purchases`, query key `["organizationAiCreditPurchase"]`. Response is `OrganizationAiCreditPurchase | null` (no wrapper). Pattern: `useOrganizationAiCreditBalance.ts`.
  - [ ] **H.2.2** `useCheckoutAiCreditPack` — POST `/ai_credit_purchases/checkout`, variables key `{ organizationAiCreditPurchase: { stripePriceLookupKey } }`. On success: invalidate `["organizationAiCreditPurchase"]`.
  - [ ] **H.2.3** `usePurchaseAiCreditTopUp` — POST `/ai_credit_purchases/purchase_top_up`, variables key `{ organizationAiCreditPurchase: { stripePriceLookupKey } }`. On success: invalidate `["organizationAiCreditBalance"]`.
  - [ ] **H.2.4** `useCancelAiCreditSubscription` — PUT `/ai_credit_purchases/cancel`. On success: invalidate `["organizationAiCreditPurchase"]` and `["organizationAiCreditBalance"]`.
  - [ ] **H.2.5** `useOrganizationAiCreditPurchasePrices` — GET `/ai_credit_purchases/prices`, query key `["organizationAiCreditPurchasePrices"]`.
  - [ ] **H.2.6** Delete old hook files: `useAiCreditSubscription.ts`, `useSubscribeToAiCreditPack.ts`, `usePurchaseAiCreditTopUp.ts`, `useCancelAiCreditSubscription.ts`
- [ ] **H.3** `app/javascript/shared/lib/planHelpers.ts` (Note #9B-2): append `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` constant and `aiCreditPrices` function (exact code from SPEC.md / approved-decisions.md)
- [ ] **H.4** `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx` (Notes #9A, #9B-1, #9B-2):
  - [ ] **H.4.1** Replace all four old hook imports with imports from `useOrganizationAiCreditPurchase.ts`
  - [ ] **H.4.2** Add import for `useOrganizationAiCreditPurchasePrices` from same file
  - [ ] **H.4.3** Add import for `aiCreditPrices` from `planHelpers.ts`
  - [ ] **H.4.4** Remove `SUBSCRIPTION_TIERS` and `TOP_UP_TIERS` hardcoded arrays
  - [ ] **H.4.5** Remove `subscriptionData?.aiCreditSubscription` unwrap — the new hook returns the object directly (or null)
  - [ ] **H.4.6** Add `useOrganizationAiCreditPurchasePrices()` hook call. Use `aiCreditPrices(pricesData)` to build the pack list; partition by `kind` into subscription and top-up arrays
  - [ ] **H.4.7** Update all `subscribe` call sites to use `useCheckoutAiCreditPack` (renamed function, updated variables key)
  - [ ] **H.4.8** Update `purchase` call sites to use the new `usePurchaseAiCreditTopUp` (updated variables key)
  - [ ] **H.4.9** Update import of `AiCreditSubscription` type to `OrganizationAiCreditPurchase` from renamed file
- [ ] **H.5** `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` (Notes #34, #13):
  - [ ] **H.5.1** Update import: rename `AiCreditsExhaustedPayload` to `AiSummaryFailedPayload`, add `AiSummaryBulkFailedPayload`
  - [ ] **H.5.2** Rename case `"AI_CREDITS_EXHAUSTED"` to `"AI_SUMMARY_FAILED"`: cast payload as `AiSummaryFailedPayload`, change toast title to `` `AI summary for ${payload.candidateFullName} could not be generated — ${payload.errorMessage}` ``
  - [ ] **H.5.3** Add case `"AI_SUMMARY_BULK_FAILED"`: cast payload as `AiSummaryBulkFailedPayload`, toast with `payload.message` as title, `kind: "warning"`, `delay: 20000`, invalidate `jobApplicationsForStage`, `jobApplication`, `organizationAiCreditBalance`
- [ ] **H.6** `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx` (Note #5):
  - [ ] **H.6.1** Update field name from `autoGenerateAiSummariesSetting` to `autoGenerateAiSummaries`
  - [ ] **H.6.2** Update the options import from `jobAutoGenerateAiSummariesSettingOptions` to `jobAutoGenerateAiSummariesOptions`
  - [ ] **H.6.3** Update default value from `"inherit"` to `"default"`
- [ ] **H.7** `app/javascript/ats/src/views/accountAdmin/OrganizationAiSettings.tsx` (Note #5):
  - [ ] **H.7.1** Update state key from `defaultAutoGenerateAiSummariesEnabled` to `autoGenerateAiSummariesEnabled`
  - [ ] **H.7.2** Update all references to the old key in the component

---

### Phase I — Plato AI Container (Note #16)

**Why last among frontend:** This is a new navigation structure; it depends on the existing AI components working correctly.

**cursor_rules to read:** `cursor_rules/frontend_base.md`, `cursor_rules/frontend_patterns.md`

- [ ] **I.1** Create directory `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/` and create `AccountPlatoAiContainer.tsx`. Pattern: `AccountIntegrationsContainer.tsx`.
  - [ ] **I.1.1** Admin-only gate via `useAuthorization({ adminOnly: true })`
  - [ ] **I.1.2** Internal sidebar NavItems: Settings (to `${match.url}/settings`), Billing (to `${match.url}/billing`), Usage (to `${match.url}/usage`)
  - [ ] **I.1.3** Switch/Route for `settings` rendering `OrganizationAiSettings`, `billing` rendering `OrganizationAiBilling`, `usage` rendering `OrganizationAiUsage`
  - [ ] **I.1.4** Default redirect to `${match.url}/settings`
  - [ ] **I.1.5** Styled components match `AccountIntegrationsContainer` exactly: `Styled.Container` (flex, height 100%), `Styled.Sidebar` (40vw / 33.333% at lg, border-right), `Styled.Content` (66.666%, overflow-y auto)
  - [ ] **I.1.6** `Helmet` title: "Plato AI"
- [ ] **I.2** Update `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx`:
  - [ ] **I.2.1** Remove imports for `OrganizationAiSettings`, `OrganizationAiBilling`, `OrganizationAiUsage`
  - [ ] **I.2.2** Add import for `AccountPlatoAiContainer` from `./accountPlatoAi/AccountPlatoAiContainer`
  - [ ] **I.2.3** In `adminOrgPathNames`: replace the three AI entries (`/hire/settings/ai`, `/hire/settings/ai-billing`, `/hire/settings/ai-usage`) with one entry: `"/hire/settings/plato-ai": "Plato AI"`
  - [ ] **I.2.4** In `memberPathNames`: remove `"/hire/settings/ai-usage": "AI usage"`. Non-admins get no Plato AI tab.
  - [ ] **I.2.5** In `<Switch>`: remove the three AI routes (`/hire/settings/ai-billing`, `/hire/settings/ai-usage`, `/hire/settings/ai`). Add one route: `path="/hire/settings/plato-ai"` with `exact={false}`, rendering `AccountPlatoAiContainer`

---

### Phase J — Documentation (Note #19)

- [ ] **J.1** Create `lib/tasks/AI_TASKS_README.md` — document AI rake tasks in two sections: "Recurring tasks (Heroku Scheduler)" (four tasks) and "On-demand / manual tasks" (five tasks), per the content in approved-decisions.md Note #19.

---

### Phase K — Test Updates

**Why last:** All code changes are complete; tests can now reference final names/shapes.

**cursor_rules to read:** `cursor_rules/backend_base.md`

- [ ] **K.1** New mailer spec. Create `spec/mailers/ai_credit_notification_mailer_spec.rb`:
  - [ ] **K.1.1** Stubs `Emails::SendTemplateEmail`
  - [ ] **K.1.2** Tests `admin_recipients` returns correct User records (org_admin, org_owner, god_admin; excludes org_user, org_interviewer)
  - [ ] **K.1.3** Tests `low_credits` message_params (template `'user-ai-credit-balance-low'`, correct variables including `credits_remaining`)
  - [ ] **K.1.4** Tests `zero_credits` message_params (template `'user-ai-credit-balance-zero'`)
  - [ ] **K.1.5** Tests `Emails::SendTemplateEmail#send` invoked once per recipient
  - [ ] **K.1.6** `spec/support/ai_credits_test_helpers.rb`: add `create_credit_test_organization_user(organization, role:)` helper
- [ ] **K.2** Update bulk job spec with notification assertions in `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`:
  - [ ] **K.2.1** Update existing `on_complete` test to verify `notify_complete` calls mailer `.deliver_later`
  - [ ] **K.2.2** Add test: `on_complete` with succeeded == 0 && failed > 0 calls `notify_failure` which sends `AI_SUMMARY_BULK_FAILED` broadcast + `failed` mailer `.deliver_later`
  - [ ] **K.2.3** Per failure pattern #4: stub mailer methods to return `instance_double(ActionMailer::MessageDelivery)` and verify `.deliver_later` is called
- [ ] **K.3** Rename and update existing specs:
  - [ ] **K.3.1** Rename `spec/interactors/consume_ai_credits_spec.rb` to `spec/interactors/create_ai_credit_balance_transaction_spec.rb`; update class reference
  - [ ] **K.3.2** Rename `spec/policies/ai_credit_policy_spec.rb` to `spec/policies/organization_ai_credit_balance_policy_spec.rb`; update class reference
  - [ ] **K.3.3** `spec/interactors/credit_consumption_with_notifications_spec.rb`: update 3 call sites + comment from `ConsumeAiCredits` to `CreateAiCreditBalanceTransaction`
  - [ ] **K.3.4** `spec/models/organization_ai_credit_purchase_spec.rb`: update pack keys to four real packs; add `describe 'CREDIT_PACKS_BY_LOOKUP_KEY'` block
  - [ ] **K.3.5** `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`: update lookup keys to four real packs; add test for `checkout.session.completed` with `ai_credit_pack_subscription: 'true'` metadata links purchase; remove test for `checkout.session.completed` with `mode: 'payment'`; add test for `invoice.paid` with `ai_credit_pack_top_up: 'true'` metadata grants one-off credits
  - [ ] **K.3.6** `spec/interactors/apply_ai_credit_purchase_spec.rb`: update lookup keys to four real packs; remove subscription creation tests (the `else` branch no longer exists); add test for existing purchase found grants credits; add test for no existing purchase fails with `:missing_purchase`
  - [ ] **K.3.7** `spec/interactors/apply_ai_credit_refund_spec.rb`: update lookup keys to four real packs
  - [ ] **K.3.8** `spec/interactors/cancel_ai_credit_subscription_spec.rb`: update lookup keys to four real packs
  - [ ] **K.3.9** Delete `spec/initializers/ai_credit_packs_spec.rb` (coverage migrated to `spec/models/organization_ai_credit_purchase_spec.rb`)

---

## Build Order Rationale

1. **Phase A (TDD spec)** first because the Note #25 TDD requirement demands a failing spec before any code change. It must be committed against the pre-fix code.

2. **Phase B (migrations)** second because column and schema changes must precede model code that references new column names.

3. **Phase C (model/service changes)** third because these establish the renamed identifiers, new constants, fixed methods, and model validation relaxations that controllers and the webhook handler depend on. This is the largest phase but has no internal ordering constraints (all sub-steps are independent of each other). Order within Phase C is chosen to minimize git noise (renames before additions).

4. **Phase D (controllers)** fourth because the new controllers call `OrganizationAiCreditPurchase.subscription_key?`, `OrganizationAiCreditPurchase.one_off_key?`, etc. from Phase C.

5. **Phase E (webhook handler)** fifth because it depends on the model validation relaxation from C.1 (purchase records with nil `stripe_subscription_id`) and the new controller creating purchase records at checkout (D.2).

6. **Phase F (retry_on fix)** sixth because it's a one-line swap gated by the Phase A spec.

7. **Phase G (bulk notifications)** seventh because it adds methods to the job that was just fixed in Phase F, and references the correctly-ordered `discard_on`/`retry_on` blocks.

8. **Phase H (frontend)** eighth because it consumes the API endpoints and response shapes established in Phases D-E.

9. **Phase I (Plato AI container)** ninth because it restructures navigation around the components modified in Phase H.

10. **Phase J (documentation)** tenth because it documents the final state.

11. **Phase K (tests)** last because all code changes are complete and tests reference final names/shapes. (Exception: Phase A's TDD spec is written first.)

---

## Files to Create

| File | Phase |
|---|---|
| `app/controllers/api/v1/organization_ai_credit_balance_controller.rb` | D.2 |
| `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` | D.2 |
| `app/mailers/bulk_job_application_ai_summary_result_mailer.rb` | G.1 |
| `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` | H.2 |
| `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AccountPlatoAiContainer.tsx` | I.1 |
| `lib/tasks/AI_TASKS_README.md` | J |
| `spec/mailers/ai_credit_notification_mailer_spec.rb` | K.1 |

## Files to Modify

| File | What changes | Phase |
|---|---|---|
| `db/migrate/20260408040701_add_auto_generate_ai_summaries_setting_to_jobs.rb` | Rename file + class + column | B.1 |
| `db/migrate/20260311120000_create_ai_job_application_summaries.rb` | Remove `prompt_text` column | B.1 |
| `db/data/20260408040802_add_ai_settings_to_existing_organizations.rb` | Rename settings key | B.1 |
| `app/models/organization_ai_credit_purchase.rb` | Add CREDIT_PACKS constant, class methods, relax validations | C.1 |
| `app/models/job.rb` | Rename enum + cascade method | C.3 |
| `app/serializers/api/v1/job_serializer.rb` | Rename attribute | C.3 |
| `app/controllers/api/v1/jobs_controller.rb` | Rename strong param + key check | C.3 |
| `app/models/organization.rb` | Rename method, Sentry capture, rename scope method | C.3, C.7, C.11 |
| `app/controllers/api/v1/organizations_controller.rb` | Rename permitted setting | C.3 |
| `app/models/textract_result.rb` | Rename method calls, remove `saved_change_to_id?`, rename broadcast method | C.3, C.4, C.12, C.13 |
| `app/interactors/notify_zero_ai_credits.rb` | Update comment reference | C.4 |
| `app/interactors/apply_ai_credit_refund.rb` | Fix .last, remove .reload calls | C.5 |
| `app/services/ai_job_application_action/summary/generate.rb` | Remove prompt_text from two hashes | C.6 |
| `lib/tasks/ai_bulk_extract.rake` | Remove prompt_text from update calls | C.6 |
| `app/models/organization_ai_credit_balance.rb` | Remove constant + 3 methods | C.7 |
| `lib/tasks/ai_credits.rake` | Rename class method call | C.7 |
| `app/mailers/ai_credit_notification_mailer.rb` | Fix is_admin, rename templates | C.8 |
| `app/interactors/reset_daily_ai_credits.rb` | Add Flipper guard | C.9 |
| `config/initializers/01_variables.rb` | Add AI_DAILY_CREDIT_ALLOCATION | C.10 |
| `app/services/plan_feature_gate.rb` | Fix fallback, use env var, remove comment | C.10 |
| `app/interactors/validate_ai_summary_generation.rb` | Fix error string | C.13 |
| `app/jobs/stripe_webhook_handler_job.rb` | Restructure checkout.session.completed + invoice.paid handlers, update AiCreditPacks refs | C.14, E |
| `app/interactors/apply_ai_credit_purchase.rb` | Remove subscription creation logic, update refs | C.14, E |
| `config/routes.rb` | Replace AI credit routes | D.3 |
| `app/jobs/bulk_generate_ai_summaries_job.rb` | Swap declarations, add notification methods | F, G.2 |
| `app/javascript/shared/types/aiJobApplicationSummary.ts` | Reconcile types | H.1 |
| `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts` | Rename + add payload types | H.1 |
| `app/javascript/shared/types/organization.ts` | Rename settings key | H.1 |
| `app/javascript/ats/src/lib/newLookups.ts` | Rename enum type/values | H.1 |
| `app/javascript/shared/lib/planHelpers.ts` | Add credits constant + transform function | H.3 |
| `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx` | Replace hooks, remove hardcoded tiers, use prices API | H.4 |
| `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` | Rename action, add bulk failed handler | H.5 |
| `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx` | Rename field + options | H.6 |
| `app/javascript/ats/src/views/accountAdmin/OrganizationAiSettings.tsx` | Rename state key | H.7 |
| `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx` | Replace 3 AI routes with 1 Plato AI route | I.2 |
| `spec/support/ai_credits_test_helpers.rb` | Add org user helper | K.1 |
| `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` | Add retry/discard + notification assertions | A, K.2 |
| `spec/interactors/credit_consumption_with_notifications_spec.rb` | Update class references | K.3 |
| `spec/models/organization_ai_credit_purchase_spec.rb` | Update pack keys, add CREDIT_PACKS describe | K.3 |
| `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` | Update keys, add/remove webhook tests | K.3 |
| `spec/interactors/apply_ai_credit_purchase_spec.rb` | Update keys, remove creation tests, add failure test | K.3 |
| `spec/interactors/apply_ai_credit_refund_spec.rb` | Update pack keys | K.3 |
| `spec/interactors/cancel_ai_credit_subscription_spec.rb` | Update pack keys | K.3 |

## Files to Rename

| From | To | Phase |
|---|---|---|
| `app/interactors/consume_ai_credits.rb` | `app/interactors/create_ai_credit_balance_transaction.rb` | C.4 |
| `app/policies/ai_credit_policy.rb` | `app/policies/organization_ai_credit_balance_policy.rb` | D.1 |
| `app/policies/ai_credit_subscription_policy.rb` | `app/policies/organization_ai_credit_purchase_policy.rb` | D.1 |
| `app/javascript/shared/types/aiCreditSubscription.ts` | `app/javascript/shared/types/organizationAiCreditPurchase.ts` | H.1 |
| `spec/interactors/consume_ai_credits_spec.rb` | `spec/interactors/create_ai_credit_balance_transaction_spec.rb` | K.3 |
| `spec/policies/ai_credit_policy_spec.rb` | `spec/policies/organization_ai_credit_balance_policy_spec.rb` | K.3 |
| `db/migrate/20260408040701_add_auto_generate_ai_summaries_setting_to_jobs.rb` | `db/migrate/20260408040701_add_auto_generate_ai_summaries_to_jobs.rb` | B.1 |

## Files to Delete

| File | Phase |
|---|---|
| `config/initializers/ai_credit_packs.rb` | C.1 |
| `app/services/role_category_groups.rb` | C.2 |
| `app/controllers/api/v1/ai_credits_controller.rb` | D.4 |
| `app/controllers/api/v1/ai_credit_subscriptions_controller.rb` | D.4 |
| `app/javascript/shared/queryHooks/useAiCreditSubscription.ts` | H.2 |
| `app/javascript/shared/queryHooks/useSubscribeToAiCreditPack.ts` | H.2 |
| `app/javascript/shared/queryHooks/usePurchaseAiCreditTopUp.ts` | H.2 |
| `app/javascript/shared/queryHooks/useCancelAiCreditSubscription.ts` | H.2 |
| `spec/initializers/ai_credit_packs_spec.rb` | K.3 |

---

## Migration Sequence

The migration rollback/edit/re-migrate must be executed as a single coordinated sequence. The implementing agent should:

1. `bundle exec rails db:migrate:status` — record current state
2. Determine rollback target: must roll back past `20260408040802` (data migration), `20260408040701` (jobs column), AND `20260311120000` (ai_job_application_summaries table) since `prompt_text` removal requires recreating the table
3. Roll back: `bundle exec rails db:rollback` repeatedly OR `bundle exec rails db:migrate:down VERSION=20260311120000` (and then each subsequent migration down). Check the status between each step.
4. Edit the three migration files per Phase B.1
5. `bundle exec rails db:migrate` — re-runs everything forward
6. `bundle exec rails db:migrate:status` — confirm all migrations are `up`

**Data loss warning:** Rolling back `20260311120000` drops the `ai_job_application_summaries` table and `20260311120001` drops `ai_api_requests`. Any local test data in those tables will be lost. This is acceptable for a dev-only feature.

---

## Test Plan

### TDD requirement (Phase A)
- Write `retry_on`/`discard_on` assertions in `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`
- Confirm spec FAILS before Phase F code change
- Confirm spec PASSES after Phase F code change with zero spec modifications

### New specs
- `spec/mailers/ai_credit_notification_mailer_spec.rb` — first mailer spec in repo
- Notification assertions in `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`

### Updated specs (pack key changes propagate to 5 spec files)
- `spec/models/organization_ai_credit_purchase_spec.rb`
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`
- `spec/interactors/apply_ai_credit_purchase_spec.rb`
- `spec/interactors/apply_ai_credit_refund_spec.rb`
- `spec/interactors/cancel_ai_credit_subscription_spec.rb`

### Renamed specs
- Rename `consume_ai_credits_spec.rb` to `create_ai_credit_balance_transaction_spec.rb`
- Rename `ai_credit_policy_spec.rb` to `organization_ai_credit_balance_policy_spec.rb`

### Deleted specs
- `spec/initializers/ai_credit_packs_spec.rb` (coverage migrated)

### Run all AI specs
After all changes: `bundle exec rspec spec/mailers/ai_credit_notification_mailer_spec.rb spec/jobs/bulk_generate_ai_summaries_job_spec.rb spec/jobs/stripe_webhook_handler_ai_credits_spec.rb spec/interactors/create_ai_credit_balance_transaction_spec.rb spec/interactors/credit_consumption_with_notifications_spec.rb spec/interactors/apply_ai_credit_purchase_spec.rb spec/interactors/apply_ai_credit_refund_spec.rb spec/interactors/cancel_ai_credit_subscription_spec.rb spec/models/organization_ai_credit_purchase_spec.rb spec/policies/organization_ai_credit_balance_policy_spec.rb`

---

## Risks and Open Questions

1. **Migration rollback depth:** Rolling back to `20260311120000` will also roll back `20260311120001` (`create_ai_api_requests`). Verify that migration has no in-place edits needed. (Confirmed: it does not appear in the spec.)

2. **`apply_top_up_checkout` removal timing:** This method is removed in Phase C.7 from `organization_ai_credit_balance.rb`, but the `checkout.session.completed` `mode == 'payment'` branch that calls it isn't removed until Phase E. Between C.7 and E, if a top-up checkout session completes, it would call a non-existent method. Mitigation: implement C.7 and E together, or implement E before C.7's removal of `apply_top_up_checkout`. Recommended: defer `apply_top_up_checkout` removal to Phase E when its caller is also removed. The plan notes this in both phases.

3. **`notify_failure` in `discard_on`/`retry_on` blocks:** These blocks are class-level and receive `|current_job, error|`. Accessing payload via `current_job.arguments.first` is the established pattern (see existing `update_remaining_statuses_to_failed`). The `notify_failure` method needs to be a class method or accessed via `new.send` — follow the existing `update_remaining_statuses_to_failed` pattern which is `private_class_method`.

4. **`invoice.paid` handler restructuring:** Moving the `board_wwr_listing_id` and `board_what_jobs_listing_id` branches above the `CustomStripeSubscriptionMissingError` guard is critical. Without this, orgs that only buy listings (no base plan) would hit the guard and raise. The spec review confirmed this ordering.

5. **Frontend type file rename:** `aiCreditSubscription.ts` to `organizationAiCreditPurchase.ts` — the implementing agent must update all import paths that reference the old file. Search for `from.*aiCreditSubscription` across the frontend.

---

## Estimated Scope

- **Files created:** 7
- **Files modified:** ~42
- **Files renamed:** 7
- **Files deleted:** 9
- **Total backend LOC changed:** ~400-500
- **Total frontend LOC changed:** ~300-400
- **Total spec LOC changed:** ~200-300
- **Estimated implementation time:** 4-6 hours with a capable agent, split across multiple sessions if needed
