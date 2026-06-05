# Approved Decisions — AI Change Spec

Source notes: `docs/ai-jessicas-notes-on-changes.md` (37 items, already prioritized — worked in existing order, no re-triage).
Frozen as-built reference: `docs/ai-system-spec-as-built-2026-05-24.md`
As-built working copy: `docs/ai-system-spec.md`

Each decision below is captured one at a time via the Decision Capture Protocol: restated in concrete content, confirmed by Jessica, then written here. The change spec is assembled only from this file.

---

## Note #1 — Fix `is_admin?` mailer bug

**Decision (confirmed):** In `app/mailers/ai_credit_notification_mailer.rb`, in the private `admin_recipients` method (line 62), change `organization.organization_users.select(&:is_admin?)` to `select(&:is_admin)` so it calls the existing `OrganizationUser#is_admin` method (`org_admin? || is_owner`). No `is_admin?` predicate exists (`is_admin` is a method, not a column), so the current call raises `NoMethodError` and both `AiCreditNotificationMailer#low_credits` and `#zero_credits` fail to deliver. After the fix, `admin_recipients` returns the org's admin/owner `User` records.

**Scope note:** Both callers (`NotifyLowAiCredits`, `NotifyZeroAiCredits`) invoke via `.deliver_later`; the `NoMethodError` currently raises inside the ActionMailer delivery job, not at the interactor call site.

**Test coverage (confirmed):** Add `spec/mailers/ai_credit_notification_mailer_spec.rb` — the first mailer spec in the repo. It stubs `Emails::SendTemplateEmail` so no real send occurs, and asserts:
- `admin_recipients` returns the `User` records for `org_admin`, `org_owner`, and `god_admin` org users and excludes `org_user` and `org_interviewer`.
- The per-recipient `message_params` outputs for both `low_credits` and `zero_credits` (`to`, `subject`, `template`, `template_version`, `tags`, and `variables` — including `credits_remaining` for `low_credits`).
- `Emails::SendTemplateEmail#send` is invoked once per recipient.

Add a reusable helper `create_credit_test_organization_user(organization, role:)` to `spec/support/ai_credits_test_helpers.rb` for building role-varied org users (anticipated reuse across policy/permission/bulk-notification specs in later notes). No FactoryBot in this repo; specs use the `AiCreditsTestHelpers` methods plus plain `create!` (bang permitted in specs).

---

## Note #2 — Reconcile `AiResumeStructuredData` to the full backend payload

**Decision (confirmed):** In `app/javascript/shared/types/aiJobApplicationSummary.ts`, reconcile `AiResumeStructuredData` (and `AiWorkExperience`) to mirror what the backend actually writes into `structured_data` (serialized verbatim by `Api::V1::AiJobApplicationSummarySerializer`, camelCased by the API layer). The type's job is to document at least the base shape the backend returns.

**Present fields (written from Call 1 extraction onward — typed as present):**
- `name`, `email`, `phone`, `location` → `string | null` (Call 1 schema allows null)
- `links`, `skills`, `certifications` → `string[]`
- `workExperience` → `AiWorkExperience[]`
- `education` → `AiEducation[]`
- `totalMonthsExperience` → `number` (`calculate_total_months` always returns an Integer, ≥ 0, never null)

**`AiWorkExperience`:** remove `roleCategory` and `relevantToJobTitle` (Call 1 `work_experience` schema never writes them). Keep `company`, `title`, `startDate`, `endDate`, `description` (`string | null`). `AiEducation` unchanged.

**Remove entirely:** `totalYearsExperience`, `relevantYearsExperience`, `jobTitleRoleCategory` (none are written by the backend).

**Optional evaluative fields (written only at later pipeline calls, so absent on partial/non-succeeded summaries — typed as optional `?`, not `| null`):**
- `roleAnalysis?`, `applicableExperience?`, `gaps?`, `overlapSummary?` → `string` (Call 4 schema: required non-null strings when present)
- `monthsByDomain?` → loose domain-name-keyed map of months (`number` values)
- `assessment?`, `comparison?` → loosely-typed (permissive) objects, NOT deeply mirrored (their inner shapes are defined by the Call 2 / Call 3 response schemas server-side; deep mirroring would re-create this drift). Loose typing aligns with core rule #12.

**Check on apply:** `AiJobApplicationSummaryFeedItem.tsx` is the sole consumer and reads only `workExperience`/`education`/`skills`/`certifications`, so removing the phantom fields breaks no existing reads. (`AiJobApplicationSummary.status` union already matches the backend enum — no change.)

---

## Note #3 — `ApplyAiCreditRefund` selects the oldest credit row

**Decision (confirmed):** In `ApplyAiCreditRefund`, change the `original_credit_row` selection from `.order(:created_at).first` to `.order(:created_at).last` (the most recent purchase-credit row for the purchase).

---

## Note #4 — AI credit top-up is gated on the wrong webhook and creates no invoice

**Problem:** The AI credit top-up checkout (`ai_credits#purchase_top_up`, `ai_credits_controller.rb:29`) does not enable `invoice_creation`, so Stripe creates no invoice. With no invoice, customers have no way to see what they've paid us, and there is no reliable signal that payment succeeded. The credit grant is gated on `checkout.session.completed` (`stripe_webhook_handler_job.rb:58`, `object.mode == 'payment'`) — the wrong webhook event.

**Fix:** Enable `invoice_creation` on the top-up checkout session and set `organization_id`, `stripe_price_lookup_key`, and `ai_credit_pack_top_up: 'true'` in `invoice_creation.invoice_data.metadata` (mirroring `board_wwr_listings_controller.rb:101-106`). Add a branch to the `invoice.paid` handler keyed on `object.metadata['ai_credit_pack_top_up']`, alongside the `board_wwr_listing_id` / `board_what_jobs_listing_id` branches, that grants the credits using the `organization_id` and `stripe_price_lookup_key` from the invoice metadata. Remove the `object.mode == 'payment'` credit-pack branch from the `checkout.session.completed` handler.

---

## Note #5 — Rename the `auto_generate_ai_summaries_setting` enum, the org default setting, and the cascade method

**Core renames:**
- Job enum (`app/models/job.rb`, keep `_prefix: true`): rename the field `auto_generate_ai_summaries_setting` to `auto_generate_ai_summaries`; rename the values `inherit` to `default`, `on` to `enabled`, and `off` to `disabled`.
- Rename the org settings key `default_auto_generate_ai_summaries_enabled` to `auto_generate_ai_summaries_enabled`.
- Rename the org method `Organization#default_auto_generate_ai_summaries_enabled?` to `Organization#auto_generate_ai_summaries_enabled` (no `?`).
- Rename the job cascade method `Job#effective_auto_generate_ai_summaries_enabled?` to `Job#should_auto_generate_ai_summaries?`.

**Migration handling (dev-only feature; no new migration):**
- Rename `db/migrate/20260408040701_add_auto_generate_ai_summaries_setting_to_jobs.rb` to `db/migrate/20260408040701_add_auto_generate_ai_summaries_to_jobs.rb` (keep the `20260408040701` timestamp); edit it in place so the column is `auto_generate_ai_summaries`.
- Edit `db/data/20260408040802_add_ai_settings_to_existing_organizations.rb` in place to seed the renamed key `auto_generate_ai_summaries_enabled` (do not rename the file; may roll it back first and re-run).

**Ripple sites (file locations only, grouped by rename):**

*Job enum rename:*
- `app/models/job.rb`
- `app/serializers/api/v1/job_serializer.rb`
- `app/controllers/api/v1/jobs_controller.rb`
- `app/javascript/ats/src/lib/newLookups.ts`
- `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx`

*Org settings key + method rename:*
- `app/models/organization.rb`
- `app/models/job.rb`
- `app/controllers/api/v1/organizations_controller.rb`
- `app/javascript/ats/src/views/accountAdmin/OrganizationAiSettings.tsx`
- `app/javascript/shared/types/organization.ts`

*Job cascade method rename:*
- `app/models/job.rb`
- `app/models/textract_result.rb`

---

## Note #6A — Move `AiCreditPacks` into `OrganizationAiCreditPurchase`

Move the `CREDIT_PACKS_BY_LOOKUP_KEY` frozen hash and its lookup methods from `config/initializers/ai_credit_packs.rb` into `OrganizationAiCreditPurchase` as constants and class methods. Delete the initializer. All callers reference `OrganizationAiCreditPurchase` instead of `AiCreditPacks`.

**Ripple sites (file locations only):**
- `app/models/organization_ai_credit_purchase.rb`
- `app/jobs/stripe_webhook_handler_job.rb`
- `app/interactors/apply_ai_credit_purchase.rb`
- `app/controllers/api/v1/ai_credits_controller.rb`
- `app/controllers/api/v1/ai_credit_subscriptions_controller.rb`
- `spec/interactors/apply_ai_credit_purchase_spec.rb`
- `spec/initializers/ai_credit_packs_spec.rb`

---

## Note #6B — Delete `RoleCategoryGroups` (dead code)

Delete `app/services/role_category_groups.rb`. It has zero references anywhere in the codebase.

---

## Note #7 — Subscription cancellation does not refund remaining balance

Verified, no change. `CancelAiCreditSubscription` only calls `Stripe::CancelCreditPackSubscription.cancel` and sets `subscription_status: :canceled` / `subscription_canceled_at` on the purchase; it never calls `ApplyAiCreditRefund` and never touches the `addon_subscription` bucket, so existing credits are preserved.

---

## Note #8 — Gate daily AI credits behind a Flipper flag (default off)

Add a Flipper flag `:AI_DAILY_CREDITS` that gates daily-credit granting per organization. Daily credits are not granted unless the flag is enabled for the org.

**Gate location:** the sole site that grants daily credits is `ResetDailyAiCredits` (it creates the `plan_daily_allocation_credit` / `:daily`-bucket grant). Gate the grant there on `Flipper.enabled?(:AI_DAILY_CREDITS, organization)`, parallel to the `:AI_APPLICANT_SUMMARY` checks. No daily grant occurs at balance creation, and `ConsumeAiCredits` already falls through a zero daily bucket to monthly, so no other gate is needed.

The per-plan daily allocation amount in `PlanFeatureGate` stays as the value used when the flag is on. When a daily-credit UI is later built, place it behind the same flag.

**Ripple sites (file locations only):**
- `app/interactors/reset_daily_ai_credits.rb`

---

## Note #9A — Restructure AI credit controllers/policies/hooks to be model-aligned

**Controllers:**
- Create `OrganizationAiCreditBalanceController` — only `#show` (balance, `render_one`).
- Create `OrganizationAiCreditPurchasesController` — `#show` (active-subscription read), `checkout` (renamed from `subscribe`), `purchase_top_up`, `cancel`. `#show` uses `render_one`, dropping the current `{ ai_credit_subscription: ... }` envelope. This changes the `#show` response shape — from a `{ ai_credit_subscription: <object | null> }` wrapper to the serialized object returned directly. The frontend read must be updated to the unwrapped shape: the subscription fetcher in the new `useOrganizationAiCreditPurchase.ts`, and its sole consumer `AccountBillingAiCredits.tsx`.
- Delete `app/controllers/api/v1/ai_credits_controller.rb` and `app/controllers/api/v1/ai_credit_subscriptions_controller.rb`.

**Routes (`config/routes.rb`, model-named controllers with short aliased paths via the `controller:` option):**
- `/ai_credits` → `OrganizationAiCreditBalanceController#show`
- `/ai_credit_purchases` → `OrganizationAiCreditPurchasesController` (`#show`, `checkout`, `purchase_top_up`, `cancel`)

**Policies:**
- Rename `AiCreditPolicy` to `OrganizationAiCreditBalancePolicy` (`#show?` stays `is_org_user?`).
- Rename `AiCreditSubscriptionPolicy` to `OrganizationAiCreditPurchasePolicy` (`#show?` stays `is_org_user?`).
- `checkout`, `purchase_top_up`, `cancel` keep authorizing via `BillingPolicy` (`create_subscription?`, `checkout?`, `cancel_subscription?`).

**Serializers (resolves note #11):** No change — `OrganizationAiCreditBalanceSerializer` and `OrganizationAiCreditPurchaseSerializer` are already model-aligned and map 1:1 to the two controllers; keep both.

**Query hooks:**
- Create `useOrganizationAiCreditPurchase.ts` and move all four hooks into it — `useAiCreditSubscription` (subscription read), `useSubscribeToAiCreditPack` (subscribe), `usePurchaseAiCreditTopUp` (purchase top-up), `useCancelAiCreditSubscription` (cancel) — updating their endpoint paths to `/ai_credit_purchases` (the subscribe path becomes `/ai_credit_purchases/checkout`).
- `useOrganizationAiCreditBalance.ts` stays standalone (still `/ai_credits`).
- Delete `useAiCreditSubscription.ts`, `useSubscribeToAiCreditPack.ts`, `usePurchaseAiCreditTopUp.ts`, `useCancelAiCreditSubscription.ts`.

**Rename:** rename the `subscribe` action to `checkout` (the controller action, its route, and the consolidated hook's function).

**Ripple sites (file locations only):**
- `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx`
- `spec/policies/ai_credit_policy_spec.rb`

---

## Note #9B-1 — Correct the AI credit pack identifiers

Replace the six fabricated packs (`ai_credits_{starter,growth,scale}_{one_off,subscription}`, 50/150/500 credits) with the four real Stripe packs:
- `ai_credit_pack_top_up_small` — one-off, 100 credits
- `ai_credit_pack_top_up_large` — one-off, 1000 credits
- `ai_credit_pack_subscription_small_monthly` — subscription, 500/month
- `ai_credit_pack_subscription_large_monthly` — subscription, 2000/month

Count drops from six packs to four (two one-off + two subscription); the frontend then shows two subscription tiers and two top-up tiers.

**Ripple sites (file locations only):**
- the pack registry (on `OrganizationAiCreditPurchase` per #6A)
- `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx`
- `spec/initializers/ai_credit_packs_spec.rb`
- `spec/models/organization_ai_credit_purchase_spec.rb`
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`
- `spec/interactors/apply_ai_credit_purchase_spec.rb`
- `spec/interactors/apply_ai_credit_refund_spec.rb`
- `spec/interactors/cancel_ai_credit_subscription_spec.rb`

---

## Note #9B-2 — Fetch pack prices from Stripe; transform via a `planHelpers` function

**Backend** — add `OrganizationAiCreditPurchasesController#prices` (route `GET /ai_credit_purchases/prices`): `Stripe::Price.list(lookup_keys: <four pack keys>, active: true, expand: ['data.product'])` → render the raw filtered Stripe list (no transform). Stripe carries no structured credit count, so the credit amount per pack is defined in `planHelpers.ts` (the `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` constant) and is not read from Stripe.

**Frontend** — in `app/javascript/shared/lib/planHelpers.ts`, add the credits constant and the `aiCreditPrices` transform that turns the (camelCased) Stripe price list into the pack objects the cards render — matching each pack's price by `lookupKey`, skipping any with no active price, deriving `kind` from `price.type`, merging credits, and ÷100 for dollars. `AccountBillingAiCredits.tsx` calls `aiCreditPrices` with the fetched prices, partitions by `kind` into the subscription/top-up sections, and matches the active subscription (`#show` per #9A) by `lookupKey` for current-state. Hardcoded tiers/prices removed.

> CODE (Jessica-approved exception to the no-code-in-spec rule):

```ts
// planHelpers.ts

// Credits per pack
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

**Fetches:** the new prices GET + the existing subscription read (`#show`); credits/transform live in `planHelpers`.

**Ripple sites (file locations only):**
- `config/routes.rb` and `OrganizationAiCreditPurchasesController`
- `app/javascript/shared/lib/planHelpers.ts`
- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`
- `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx`

---

## Note #9B-5 — Record the credit-pack subscription at checkout, mirroring how the base plan subscription is handled

Today the credit-pack subscription's `OrganizationAiCreditPurchase` record is created from a single event — the first `invoice.paid`, where `handle_credit_pack_invoice_paid` calls `ApplyAiCreditPurchase#apply_subscription` to create the row. The other two events that fire during a subscription checkout do nothing useful for it: `checkout.session.completed` finds no matching organization and silently fails, and `customer.subscription.created` is an explicit no-op. Because creation hangs on that one event, if the first `invoice.paid` is delayed, dropped, or fails, Stripe has charged the customer while we hold no record of the subscription and grant no credits, and nothing reconciles it afterward. The base plan avoids this, because it records the checkout session on the organization at checkout time and then links the Stripe subscription id when `checkout.session.completed` arrives.

The fix gives the credit-pack subscription that same two-step handshake, writing to the `OrganizationAiCreditPurchase` record instead of the organization.

At checkout, in the action currently named `subscribe`, which note #9A renames to `checkout`: after the Stripe Checkout Session is created, immediately create the `OrganizationAiCreditPurchase` row, with `kind: subscription`, `stripe_checkout_session_id` set to the new session's id, `stripe_price_lookup_key`, and `subscription_credits_per_period` derived from the chosen lookup key. Leave `subscription_status` nil, since there is no pending state. This mirrors `billing#checkout` saving `stripe_checkout_session_id` on the organization at `billing_controller.rb:113`, except that here we create the purchase record rather than update the organization.

When `checkout.session.completed` arrives, add a branch on the session metadata. When `object.metadata&.[]('ai_credit_pack_subscription') == 'true'`, this is the AI-credit subscription, so find the purchase by its `stripe_checkout_session_id` and set its `stripe_subscription_id` from `object.subscription`, without writing the organization's `stripe_subscription_id`. Otherwise the handler falls through to the existing base-plan write. This mirrors the plan's linking step at `stripe_webhook_handler_job.rb:67-73`.

When `invoice.paid` arrives, the purchase already exists and is already linked by `stripe_subscription_id`, so the lookup at the top of `handle_credit_pack_invoice_paid` finds it, and both the first invoice and every renewal run through the existing `if existing` branch at lines 443–482: it sets the status and period dates and inserts a `subscription_credit_pack_purchase_credit` ledger row granting `subscription_credits_per_period`, idempotent on the invoice id. The `else` branch, which today calls `ApplyAiCreditPurchase` to create the purchase on the first invoice, is no longer reachable, so it is removed, and `ApplyAiCreditPurchase#apply_subscription`'s record-creation logic moves into the checkout action described above.

Renewal credits need no change: the `if existing` branch already grants per period, idempotently on the invoice id.

**Ripple sites (file locations only):**
- the action currently named `subscribe`, which note #9A renames to `checkout`, on `OrganizationAiCreditPurchasesController`
- `app/jobs/stripe_webhook_handler_job.rb`
- `app/interactors/apply_ai_credit_purchase.rb`
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`
- `spec/interactors/apply_ai_credit_purchase_spec.rb`

---

## Note #10 — moot

This note requests a change to the technical map (`ai-technical-map.md`) — listing policy methods consistently across all the AI policies. The technical map is rewritten after our changes are complete regardless, so that consistency is produced by the rewrite; nothing to do here.

---

## Note #12 — Rename `ConsumeAiCredits` to `CreateAiCreditBalanceTransaction`

**Decision (confirmed):** Rename the interactor class from `ConsumeAiCredits` to `CreateAiCreditBalanceTransaction`, matching the codebase convention where the `Create*` prefix names the record the interactor primarily produces. Rename the file accordingly.

**Ripple sites (file locations only):**
- `app/interactors/consume_ai_credits.rb` — rename file to `create_ai_credit_balance_transaction.rb`, rename class
- `app/models/textract_result.rb` — call site
- `app/interactors/notify_zero_ai_credits.rb` — comment reference
- `spec/interactors/consume_ai_credits_spec.rb` — rename file to `create_ai_credit_balance_transaction_spec.rb`, update class reference
- `spec/interactors/credit_consumption_with_notifications_spec.rb` — 3 call sites + comment
- Internal logger strings inside the interactor (2 occurrences)

---

## Note #25 — Fix dead `retry_on` in `BulkGenerateAiSummariesJob` (declaration order)

**Decision (confirmed):** The `retry_on CustomErrorAiSummary` declaration in `BulkGenerateAiSummariesJob` is unreachable. ActiveJob's `rescue_from` searches handlers in reverse declaration order (last declared = first checked). Currently `discard_on StandardError` is declared after `retry_on CustomErrorAiSummary`, so `discard_on` is checked first and matches all `StandardError` subclasses — including `CustomErrorAiSummary`. Provider/connection errors are discarded immediately instead of retried.

**Spec first (TDD — must fail before the fix):** Add `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`. The spec stubs the pipeline to raise `CustomErrorAiSummary` during iteration and asserts the job is re-enqueued (retried), not discarded. Separately asserts that a non-`CustomErrorAiSummary` `StandardError` escaping outside `each_iteration` results in discard (not retry). Write and run the spec BEFORE the declaration order change. It must FAIL against the current code. No modifications to the spec are permitted after the code change — the fix alone must make it pass.

**Code change:** In `app/jobs/bulk_generate_ai_summaries_job.rb`, swap the declaration order: `discard_on StandardError` first, `retry_on CustomErrorAiSummary` second. This makes `retry_on` the first handler checked, giving provider/connection errors 3 attempts with 2-minute waits. `discard_on StandardError` becomes the fallback for anything else escaping the job framework.

**Ripple sites (file locations only):**
- `app/jobs/bulk_generate_ai_summaries_job.rb` — swap the two declarations
- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` — new spec file

---

## Note #13 — Add Email Notification on Bulk AI Summary Completion

**Decision (confirmed):** Add email notifications to the bulk AI summary job for both completion and failure, following the established export-completion pattern (`JobResumeExportMailer`, `OrganizationDataExportMailer`). Sends to the triggering user only.

**Mailer:** New `BulkJobApplicationAiSummaryResultMailer` in `app/mailers/bulk_job_application_ai_summary_result_mailer.rb`. Two methods, ID-based args.

**`complete` method:**
- Template: `user-bulk-ai-summary-complete`
- Subject: `"Your AI summaries for #{job_title} are ready"`
- Variables: `user_first_name`, `job_title`, `succeeded_count`, `failed_count`, `skipped_count`, `hiring_stage_link`

**`failed` method:**
- Template: `user-bulk-ai-summary-failed`
- Subject: `"We couldn't generate AI summaries for #{job_title}"`
- Variables: `user_first_name`, `job_title`, `total_queued_count` (the total originally initiated: `payload['job_application_ids'].size + payload['skipped_count']`)

**Failure condition:** succeeded == 0 AND failed > 0. All other cases use `complete`.

**Two helper methods on `BulkGenerateAiSummariesJob`:**

`notify_complete` — sends the `AI_SUMMARY_BULK_COMPLETE` GlobalChannel broadcast + `BulkJobApplicationAiSummaryResultMailer.complete(...).deliver_later`. Called from `on_complete` when the failure condition is NOT met.

`notify_failure` — sends a new failure-specific GlobalChannel broadcast + `BulkJobApplicationAiSummaryResultMailer.failed(...).deliver_later`. Called from three places:
1. `discard_on` block
2. `retry_on` exhaustion block
3. `on_complete` when the failure condition IS met (succeeded == 0, failed > 0)

**`on_complete` becomes a clean branch:** evaluate counts, call either `notify_complete` or `notify_failure`. No inline broadcast/mailer logic in `on_complete` itself.

**GlobalChannel failure broadcast** (new action, distinct from `AI_SUMMARY_BULK_COMPLETE`). Payload includes `job_title` and a user-facing message.

**Frontend:** New WebSocket action handler in `WebsocketGlobalChannelHandler.tsx` for the bulk failure broadcast. New payload type in `aiSummaryWebsocketPayloads.ts`.

**Ripple sites (file locations only):**
- `app/mailers/bulk_job_application_ai_summary_result_mailer.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`
- `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts`

---

## Note #14 — Table Review

**Decision (confirmed):** No change. Both tables are kept as-is; the three aggregate methods on `AiJobApplicationSummary` (`total_cost`, `total_input_tokens`, `total_output_tokens`) are kept for Rails console use.

**`OrganizationAiCreditPurchase`:** Confirmed necessary — it is the idempotency key for Stripe webhook retries (keyed on `stripe_checkout_session_id` / `stripe_subscription_id`). Without it, duplicate credit grants are possible. It also links purchases to ledger transactions and tracks subscription period dates.

**`AiApiRequest`:** Well-designed, follows industry standard practice. Per-call logging with full prompt/response is the baseline for production AI apps — every major LLM observability platform (Helicone, LangSmith, Langfuse) does this by default.

Key reasons to keep it:
- Quality monitoring / regression detection when changing prompts or models
- Fine-tuning dataset construction (filter good responses as training data)
- Cost optimization (identify expensive calls)
- Billing model migration (backtest usage-based pricing against historical actuals — per-call costs cannot be reconstructed retroactively)
- Compliance/audit trails for enterprise customers

Storage is fine at current scale. 4 rows per summary, ~16–40KB per summary. Even at 10,000 summaries/month that's 160–400MB/month — trivial for Postgres. The only future concern is adding an archival policy (e.g., move rows older than 90 days to S3) once the table grows large enough to be a maintenance burden.

The three aggregate methods on `AiJobApplicationSummary` (`total_cost`, `total_input_tokens`, `total_output_tokens`) have no application-code callers but are kept as Rails console convenience methods for ad-hoc cost and token inspection.

---

## Note #15 — removed

Note #15 Jessica said was irrelevant, removed.

---

## Note #19 — Document AI rake tasks in `lib/tasks/AI_TASKS_README.md`

**Decision (confirmed):** Create `lib/tasks/AI_TASKS_README.md` (heading `# AI Tasks`) documenting the AI-related rake tasks in two sections.

**Recurring tasks (Heroku Scheduler):**
- `ai_credits:reset_daily` — daily. Resets the daily AI credit bucket for every org. Only grants when the `:AI_DAILY_CREDITS` Flipper flag is enabled for the org (per note #8). Not enabled at initial launch.
- `ai_credits:process_overdue_resets` — daily. Safety-net that resets monthly credits for orgs whose billing period end is >6 hours past due.
- `ai_credits:reconcile` — daily. Rebuilds cached credit counters from the ledger (per note #23).
- `ai_credits:cleanup_orphaned_bulk_claims` — daily. Sweeps `BulkAiSummaryJobApplication` rows stuck in `processing` for >24 hours (worker hard-death recovery).

**On-demand / manual tasks:**
- `ai_credits:grant[org_id,amount,"reason"]` — manually grant credits to an org.
- `ai_credits:show[org_id]` — display current credit state + last 10 transactions.
- `ai:bulk_extract ORG_ID=N` — bulk run Call 1 (structured data extraction) for an org.
- `ai:relevance_benchmark ORG_ID=N JOB_IDS=N LIMIT=N` — full pipeline benchmark (Calls 2–4) across model combinations.
- `ai:comparison_benchmark ORG_ID=N JOB_ID=N LIMIT=N` — benchmark Call 3 across flash/haiku/sonnet.

---

## Notes #20 + #38 — Create Mailgun templates and fix template name convention

**Decision (confirmed):** Rename the template references in `AiCreditNotificationMailer` from `ai-credits-low` to `user-ai-credit-balance-low` and from `ai-credits-zero` to `user-ai-credit-balance-zero`.

Four Mailgun templates to create before deploy (early enough to test):
- `user-ai-credit-balance-low` — `ai_credit_notification_mailer.rb`
- `user-ai-credit-balance-zero` — `ai_credit_notification_mailer.rb`
- `user-bulk-ai-summary-complete` — `bulk_job_application_ai_summary_result_mailer.rb`
- `user-bulk-ai-summary-failed` — `bulk_job_application_ai_summary_result_mailer.rb`

**Ripple sites (file locations only):**
- `app/mailers/ai_credit_notification_mailer.rb` (two template string references)

---

## Note #21 — Resume re-upload confirmation modal: not needed

**Decision (confirmed):** No change. When auto-generate is on, the organization has already made the decision to consume credits automatically — a per-re-upload modal would contradict that setting. Additionally, resume re-uploads are low-incidence because resumes are managed by the hiring team, not by the candidate.

---

## Note #23 — Schedule `ai_credits:reconcile` as automatic housekeeping

**Decision (confirmed):** Already covered by note #19 — `ai_credits:reconcile` is listed as a daily Heroku Scheduler task in the `AI_TASKS_README.md` decision.

---

## Note #24 — `BulkGenerateAiSummariesJob` max runtime: no change

**Decision (confirmed):** Keep `job_iteration_max_job_runtime` at 10 minutes. The job-iteration gem (`JobIteration::Iteration`) handles runtime limits gracefully — when the limit is reached, the job pauses at the current cursor position and re-enqueues itself. The batch does not fail; it resumes from where it left off in a new job execution. Each completed iteration updates the per-job-application bulk job status to `:done` before advancing the cursor, so no work is lost or duplicated on re-enqueue. Shorter runtimes are preferable because this job runs on the `default` queue alongside jobs that complete in seconds.

---

## Note #26 — Remove `prompt_text` from `AiJobApplicationSummary`

**Decision (confirmed):** Remove `prompt_text` from `AiJobApplicationSummary` entirely. The per-call prompt data is already stored in `AiApiRequest.prompt_text`, which is the authoritative record.

**Migration handling (dev-only feature; no new migration):** Roll back to before `20260311120000_create_ai_job_application_summaries`, edit the migration in place to remove the `t.text :prompt_text` line, then re-migrate.

**Remove the three write sites:**
- `app/services/ai_job_application_action/summary/generate.rb` (two writes: after Call 1 at line 67, and in the final success update at line 168)
- `lib/tasks/ai_bulk_extract.rake` (one write at line 63)

---

## Note #27 — Remove redundant overdue check chain; rename `process_overdue_ai_credit_resets`

**Decision (confirmed):**

1. Remove `period_overdue?` (line 30 on `OrganizationAiCreditBalance`)
2. Remove `OVERDUE_RESET_GRACE` (line 4) — only used by `period_overdue?`
3. Remove `reset_ai_credits_if_overdue` (line 49) — without `period_overdue?` it's a bare delegation to `reset_ai_credits`
4. Rename `process_overdue_ai_credit_resets` to `process_ai_credit_resets` on `Organization`
5. In `process_ai_credit_resets`, replace the call to `reset_ai_credits_if_overdue` with `org.organization_ai_credit_balance.reset_ai_credits`

**Ripple sites (file locations only):**
- `app/models/organization_ai_credit_balance.rb` (remove constant, two methods)
- `app/models/organization.rb` (rename method, replace call)
- `lib/tasks/ai_credits.rake` (update call at line 76)

---

## Note #28 — AI Credit Allocation Constants

**Decision (confirmed):** No change. The bare `500` literal for `plan_ats_tier_enterprise` in `PlanFeatureGate#plan_rules` is intentional. The other tier constants (`STARTER_AI_CREDIT_ALLOCATION`, `GROWTH_AI_CREDIT_ALLOCATION`, `SCALE_AI_CREDIT_ALLOCATION`) each exist because they appear twice — once in the legacy plan entry and once in the v2 entry. Enterprise has a single plan entry (no legacy/v2 split), so a named constant adds no deduplication value. The enterprise plan is not in active use.

---

## Note #29 — Daily Reset Idempotency Check Outside Transaction

**Decision (confirmed):** No change. The idempotency check in `ResetDailyAiCredits` (lines 16-22) runs outside the transaction, which is technically raceable under concurrent execution. But the sole caller is `ai_credits:reset_daily` (a once-daily Heroku Scheduler cron job), so the only concurrency scenario is a stuck/slow prior run overlapping the next. Daily credits are not currently active. Accept the current state; revisit if daily credits are activated and concurrency becomes a real concern.

---

## Note #30 — `create_ai_credit_state_if_needed` Silent Failure

**Decision (confirmed):** Add `Sentry.capture_exception(e)` to the rescue block in `Organization#create_ai_credit_state_if_needed`. Keep the existing `Rails.logger.error` and `ap`. No re-raise — org creation still succeeds, but the failure becomes visible in Sentry instead of buried in logs.

**Ripple sites (file locations only):**
- `app/models/organization.rb`

---

## Note #31 — PlanFeatureGate Unknown-Plan Fallback Asymmetry

**Decision (confirmed):** Two changes:

1. Fix the fallback asymmetry in `PlanFeatureGate#daily_ai_credit_allocation`: change from `plan_rules[@plan]&.dig(:daily_ai_credit_allocation)` (returns `nil` for unknown plans) to `plan_rules[@plan]&.dig(:daily_ai_credit_allocation) || DAILY_AI_CREDIT_ALLOCATION`, matching the monthly method's fallback pattern.

2. Make the daily allocation configurable via env var: add `AI_DAILY_CREDIT_ALLOCATION = ENV['AI_DAILY_CREDIT_ALLOCATION']&.to_i || 5` to `config/initializers/01_variables.rb`. Change `PlanFeatureGate::DAILY_AI_CREDIT_ALLOCATION` to read from `Variables::AI_DAILY_CREDIT_ALLOCATION` instead of hardcoding `5`. Default stays `5`; setting the env var on Heroku overrides it.

**Ripple sites (file locations only):**
- `config/initializers/01_variables.rb`
- `app/services/plan_feature_gate.rb`

---

## Note #32 — `ApplyAiCreditRefund` Uses `.reload`

**Decision (confirmed):** Remove both `.reload` calls in `ApplyAiCreditRefund`. Line 21: the association chain `purchase.organization.organization_ai_credit_balance` is accessed for the first time in this interactor (loaded fresh from DB on first access); `.reload` is redundant — change to `purchase.organization.organization_ai_credit_balance`. Line 62: `purchase.update(updates)` already mutates the in-memory object; `.reload` re-reads what `update` already applied — change to `context.purchase = purchase`.

**Ripple sites (file locations only):**
- `app/interactors/apply_ai_credit_refund.rb`

---

## Note #33 — Webhook Silently Drops Refunds When Purchase Isn't Matched

**Decision (confirmed):** No change. `handle_charge_refunded` handles ALL `charge.refunded` events, not just credit-pack refunds. The `return unless purchase` correctly filters non-credit-pack refunds (regular plan subscription refunds have no matching `OrganizationAiCreditPurchase`). A credit-pack refund failing to match would require a Stripe ID sync mismatch (`stripe_subscription_id` or `stripe_checkout_session_id`), which indicates a larger data integrity problem that wouldn't be caught by logging at this point.

---

## Note #34 — `AI_CREDITS_EXHAUSTED` Action Name Mismatches Its Trigger

**Decision (confirmed):** Rename the action and pass the actual error message through to the frontend.

Backend:
- Rename `broadcast_credits_exhausted` to `broadcast_ai_summary_failed` on `TextractResult`
- Rename the WebSocket action from `AI_CREDITS_EXHAUSTED` to `AI_SUMMARY_FAILED`
- Add `errorMessage` to the payload (the `context.error` string from `ValidateAiSummaryGeneration`)
- Change the line 29 error string in `ValidateAiSummaryGeneration` from `'Resume processing has failed. Try uploading a different file.'` to `'Resume processing has failed. Try uploading a different resume file.'`

Frontend:
- `WebsocketGlobalChannelHandler.tsx`: rename the case to `AI_SUMMARY_FAILED`, update the payload type, use `payload.errorMessage` as the toast title instead of the hardcoded credit message. Keep the `AI summary for ${candidateFullName} could not be generated —` prefix with the error message after the dash.

**Ripple sites (file locations only):**
- `app/models/textract_result.rb`
- `app/interactors/validate_ai_summary_generation.rb`
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`

---

## Note #35 — `saved_change_to_id?` Check in `queue_ai_summary_job` Is Redundant

**Decision (confirmed):** Remove `|| saved_change_to_id?` from `textract_result.rb:97`. The `saved_change_to_textract_job_result_text?` guard already covers the create case (AR dirty tracking marks all set attributes as changed on insert), and in production text is never set at insert — `SubmitResumeToTextract` creates with only `textract_job_id` and status; `GetResumeTextFromTextract` adds text later via `update`.

**Ripple sites (file locations only):**
- `app/models/textract_result.rb`

---

## Note #36 — `PlanFeatureGate` Does Not Actually Gate AI Summaries

**Decision (confirmed, revised):** No change. `AI_APPLICANT_SUMMARY` correctly belongs in `universal_features` — available to all plans including free. The feature itself is not plan-gated. Access is controlled by two other mechanisms: Flipper (rollout control) and credits (usage control). A free-plan org that buys credit packs should be able to use AI summaries. Denying the feature at the plan level would hide UI for credits they paid for.

---

## Note #37 — Misleading Comment in `plan_feature_gate.rb`

**Decision (confirmed):** Remove the comment on line 76 (`# Universal features available to all tier 1 and tier 2 paid plans`). The method name `universal_features` is self-documenting.

**Ripple sites (file locations only):**
- `app/services/plan_feature_gate.rb`

---

<!-- Decisions appended below as they are confirmed -->

