# Implementation Plan: Custom AI Credit Subscription Upgrade/Downgrade

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Summary

Replace the Stripe customer portal-based AI credit subscription change flow with direct Stripe API calls and a custom confirmation modal. Two new controller actions (`preview_subscription_change`, `commit_subscription_change`) replace three portal actions. A new `ApplyAiCreditUpgrade` interactor grants the credit difference on upgrade invoices. A new `ScheduleAiCreditSubscriptionDowngrade` interactor schedules downgrades at period end via `Stripe::SubscriptionSchedule`. The webhook handler routes `subscription_update` invoices to the new interactor. A new `UpdateAiCreditSubscriptionConfirmModal` component shows real Stripe preview amounts. Three portal controller actions, three routes, two frontend mutation hooks, and two frontend handler functions are removed.

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/`

**Spec:** `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/SPEC.md`

---

## Pattern precedents

### Controller action pattern (authorization, purchase lookup, guards, Stripe call, error handling)

**Analog:** `cancel` action in `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (lines 193-214)

```
- Line 194: authorize :billing, :cancel_subscription?
- Line 196: subscription = current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])
  NOTE: The cancel action uses the variable name `subscription` -- the new actions must NOT copy this. Use `organization_ai_credit_purchase` per naming rules.
- Lines 197-200: guard with render_general_errors + return
- Lines 201-208: Stripe call + response
- Lines 209-214: method-level rescue Stripe::StripeError => e with Rails.logger.error, ap e, Sentry.capture_exception, render_general_errors
```

**Second analog:** `change_subscription_portal_session` (lines 233-281) -- same authorization (`authorize :billing, :change_subscription?`), same purchase lookup, `raise StandardError` guards (lines 239-241), `determine_price_id` usage. Multi-rescue pattern: `Pundit::NotAuthorizedError`, `Stripe::InvalidRequestError`, `StandardError`.

**Third analog:** `customer_subscription` action (lines 422-437) -- shows the Stripe object retrieval + JSON rendering pattern.

### Interactor pattern (include Interactor, context.fail!, ApplicationRecord.transaction, fail_with_record_invalid)

**Analog:** `app/interactors/apply_ai_credit_purchase.rb` (91 lines)

```
- Line 10: include Interactor
- Line 39: idempotency check (return if stripe_invoice_id == invoice.id)
- Line 41: balance = organization.organization_ai_credit_balance
- Lines 53-79: ApplicationRecord.transaction block
  - Line 54-59: organization_ai_credit_purchase.update(...) with return value check
  - Line 62: organization_ai_credit_purchase.finalize_stripe_payment
  - Lines 64-71: AiCreditBalanceTransaction.new(...).save with return value check
  - Lines 74-78: balance.update(...) notification flag reset with return value check
- Lines 82-90: fail_with_record_invalid private method (local, not shared)
```

**Second analog:** `app/interactors/cancel_ai_credit_subscription.rb` (54 lines)

```
- Line 28: include Interactor
- Line 31: purchase = context.purchase (NOTE: uses shortened variable name -- DO NOT copy)
- Line 33: Stripe call first (Stripe::CancelCreditPackSubscription.cancel)
- Lines 35-42: local state update with return value check
- Lines 45-52: rescue Stripe::StripeError => e, context.fail!(error: :stripe_error, ...)
```

**Service wrapper analog:** `app/services/stripe/cancel_credit_pack_subscription.rb` (25 lines) -- thin class-method wrapper around `Stripe::Subscription.update`. The downgrade interactor makes the Stripe call directly (multi-step SubscriptionSchedule API) rather than through a service wrapper.

### React Query mutation hook pattern

**Analog:** `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`

Cancel hook (lines 127-139):
```
- Async function: apiPut with path and variables
- useMutation wrapper
- onSuccess: queryClient.invalidateQueries for organizationAiCreditPurchase + organizationAiCreditBalance
```

Portal hooks being replaced (lines 35-48, 50-62, 64-77, 79-91):
```
- Async function: apiPost with path and variables
- useMutation wrapper
- onSuccess: invalidates currentOrganization + organizationAiCreditPurchase
```

### CenterModal component pattern

**Analog:** `app/javascript/ats/src/views/accountAdmin/accountBilling/CancelAiCreditSubscriptionConfirmModal.tsx` (73 lines)

```
- Line 5: import CenterModal from "@ats/src/components/modals/CenterModal"
- Line 6: import Button from "@ats/src/components/shared/Button"
- Lines 9-14: Props interface with onCancel, onConfirm, isLoading?, data props
- Line 27: <CenterModal headerTitleText="..." onCancel={onCancel}> (no hasUnsavedChanges)
- Line 39: <Button onClick={onConfirm} disabled={isLoading} dangerous>
- Line 50: const Styled: any = {};
```

**Second analog:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/PurchaseAiCreditTopUpConfirmModal.tsx` (61 lines) -- same CenterModal pattern, same Styled pattern, but NO isLoading/disabled on Button (known failure pattern #11).

### Styled component pattern

Both billing modal analogs use:
```typescript
const Styled: any = {};

Styled.Body = styled.div((props: any) => {
  const t: any = props.theme;
  return css`
    label: ComponentName_Body;
    ...
  `;
});
```

This is the `const` variant. The handoff file uses `let Styled: any; Styled = {};` -- both patterns exist in the codebase, but the modal analogs use `const`. The plan uses the handoff file's `let` variant because the handoff defines the visual design, and the spec says to use `let Styled: any; Styled = {};`.

---

## Files to create or modify (complete list)

### Backend -- new files
| # | File | Purpose |
|---|------|---------|
| 1 | `app/interactors/apply_ai_credit_upgrade.rb` | Upgrade credit granting interactor |
| 2 | `app/interactors/schedule_ai_credit_subscription_downgrade.rb` | Downgrade scheduling interactor |

### Backend -- modified files
| # | File | What changes |
|---|------|-------------|
| 3 | `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` | Add `preview_subscription_change` + `commit_subscription_change`; remove `change_subscription_portal_session` + `update_payment_method_and_subscription_portal_session` + `continue_change_subscription_portal_session` |
| 4 | `app/jobs/stripe_webhook_handler_job.rb` | Add `billing_reason` branch in `handle_subscription_credit_pack_invoice_paid` |
| 5 | `config/routes.rb` | Remove 3 portal routes, add 2 new routes |

### Frontend -- new files
| # | File | Purpose |
|---|------|---------|
| 6 | `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx` | Confirmation modal |

### Frontend -- modified files
| # | File | What changes |
|---|------|-------------|
| 7 | `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` | Add 2 new hooks; remove 2 portal hooks + functions + exports |
| 8 | `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` | Replace portal flow with preview+modal+commit; update imports and loading states |
| 9 | `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts` | Add "Downgrade" to `deriveTierButtonText` |

### Test files -- new
| # | File | Purpose |
|---|------|---------|
| 10 | `spec/interactors/apply_ai_credit_upgrade_spec.rb` | Interactor spec |
| 11 | `spec/interactors/schedule_ai_credit_subscription_downgrade_spec.rb` | Interactor spec |
| 12 | `spec/controllers/api/v1/organization_ai_credit_purchases_subscription_change_spec.rb` | Controller spec for new actions |

### Test files -- modified/removed
| # | File | What changes |
|---|------|-------------|
| 13 | `spec/controllers/api/v1/organization_ai_credit_purchases_change_subscription_spec.rb` | Remove entirely (tests portal actions being deleted) |
| 14 | `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` | Add `billing_reason` routing test cases |

### Not modified (verified)
| File | Reason |
|------|--------|
| `app/models/organization_ai_credit_purchase.rb` | No new columns, methods, or enums |
| `app/models/ai_credit_balance_transaction.rb` | No new `entry_type` or `bucket` values |
| `app/models/organization_ai_credit_balance.rb` | No changes |
| `app/interactors/apply_ai_credit_purchase.rb` | Continues to handle renewal/first-invoice grants unchanged |
| `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb` | No new attributes |
| `app/policies/billing_policy.rb` | `change_subscription?` already exists (line 24) |
| `app/javascript/shared/types/organizationAiCreditPurchase.ts` | No new fields |
| `app/javascript/shared/lib/planHelpers.ts` | Already has required constants |

---

## A. Backend changes

### A.1 Routes

- [ ] **A.1.1** Read `cursor_rules/core_critical_rules.md` rule 4 (PUT for updates)
- [ ] **A.1.2** Open `config/routes.rb` and locate the `ai_credit_purchases` resource block (lines 190-201)
- [ ] **A.1.3** Remove these three lines:
  - Line 195: `post :change_subscription_portal_session`
  - Line 196: `post :update_payment_method_and_subscription_portal_session`
  - Line 200: `get :continue_change_subscription_portal_session`
- [ ] **A.1.4** Add these two lines in the collection block (after `purchase_top_up_checkout_session`, before `put :cancel`):
  ```ruby
  post :preview_subscription_change
  post :commit_subscription_change
  ```

### A.2 Controller: Add `preview_subscription_change` action

**Read before working:** `cursor_rules/core_critical_rules.md` (rules 1, 3, 7, 8, 11, 12), `cursor_rules/backend_controllers_base.md`

- [ ] **A.2.1** Open `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`
- [ ] **A.2.2** Add `preview_subscription_change` action. Place it where the removed `change_subscription_portal_session` was (around line 233). The action:
  1. `authorize :billing, :change_subscription?`
  2. Find active subscription purchase: `organization_ai_credit_purchase = current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])`
  3. Guards (matching `cancel` action pattern -- `render_general_errors` + bare `return`, NOT `raise StandardError`):
     ```ruby
     unless current_organization.stripe_customer_id.present?
       render_general_errors(['Stripe customer ID missing.'])
       return
     end
     unless organization_ai_credit_purchase
       render_general_errors(['No active AI credit subscription found.'])
       return
     end
     unless organization_ai_credit_purchase.stripe_subscription_id.present?
       render_general_errors(['Subscription ID missing.'])
       return
     end
     ```
     NOTE: The portal actions used `raise StandardError` with a multi-rescue block. The new actions use the `cancel` action pattern instead (single `rescue Stripe::StripeError`). Using `raise StandardError` without a `rescue StandardError` handler would return raw 500 errors.
  4. Retrieve live Stripe subscription: `stripe_subscription = Stripe::Subscription.retrieve(organization_ai_credit_purchase.stripe_subscription_id)`
  5. Call `Stripe::Invoice.create_preview`:
     ```ruby
     preview = Stripe::Invoice.create_preview(
       customer: current_organization.stripe_customer_id,
       subscription: organization_ai_credit_purchase.stripe_subscription_id,
       subscription_details: {
         items: [{
           id: stripe_subscription.items.data.first.id,
           price: determine_price_id
         }],
         proration_behavior: 'always_invoice',
         proration_date: organization_ai_credit_purchase.subscription_current_period_start.to_i
       }
     )
     ```
  6. Build payment method info:
     ```ruby
     payment_method_id = stripe_subscription.default_payment_method ||
       Stripe::Customer.retrieve(current_organization.stripe_customer_id).invoice_settings&.default_payment_method
     default_payment_method = if payment_method_id
       pm = Stripe::PaymentMethod.retrieve(payment_method_id)
       { brand: pm.card.brand, last4: pm.card.last4 }
     end
     ```
  7. Build and render JSON response:
     ```ruby
     render json: {
       amount_due: preview.amount_due,
       currency: preview.currency,
       lines: preview.lines.data.map { |line|
         {
           amount: line.amount,
           description: line.description,
           price: { lookup_key: line.price.lookup_key }
         }
       },
       subscription_item_id: stripe_subscription.items.data.first.id,
       current_period_end: stripe_subscription.current_period_end,
       default_payment_method: default_payment_method
     }
     ```
  8. Method-level rescue (matching `cancel` action pattern at lines 209-214):
     ```ruby
     rescue Stripe::StripeError => e
       Rails.logger.error "Stripe error previewing subscription change: #{e.message}"
       ap e
       Sentry.capture_exception(e, extra: { org_id: current_organization&.id, action: 'organization_ai_credit_purchases#preview_subscription_change' })
       render_general_errors(['Unable to load subscription preview. Please try again.'])
     ```

- [ ] **A.2.3** Verify `determine_price_id` (lines 448-454) reads `params[:price_id]` -- the frontend sends `priceId` which the API layer transforms to `price_id`. No changes needed to `determine_price_id`.

### A.3 Controller: Add `commit_subscription_change` action

**Read before working:** Same cursor_rules as A.2

- [ ] **A.3.1** Add `commit_subscription_change` action after `preview_subscription_change`. The action:
  1. `authorize :billing, :change_subscription?`
  2. Same purchase lookup and guards as `preview_subscription_change` (A.2.2 steps 2-3)
  3. Retrieve new price from Stripe to get lookup key:
     ```ruby
     new_price = Stripe::Price.retrieve(determine_price_id)
     new_lookup_key = new_price.lookup_key
     ```
  4. Determine upgrade vs downgrade server-side:
     ```ruby
     current_credits = OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(
       organization_ai_credit_purchase.stripe_price_lookup_key
     )
     new_credits = OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(new_lookup_key)
     is_downgrade = new_credits < current_credits
     ```
  5. For upgrades (`!is_downgrade`): retrieve Stripe subscription and call `Stripe::Subscription.update` with identical params to preview:
     ```ruby
     stripe_subscription = Stripe::Subscription.retrieve(
       organization_ai_credit_purchase.stripe_subscription_id
     )
     Stripe::Subscription.update(
       organization_ai_credit_purchase.stripe_subscription_id,
       {
         items: [{
           id: stripe_subscription.items.data.first.id,
           price: determine_price_id
         }],
         proration_behavior: 'always_invoice',
         proration_date: organization_ai_credit_purchase.subscription_current_period_start.to_i
       }
     )
     ```
  6. For downgrades (`is_downgrade`): delegate to interactor:
     ```ruby
     result = ScheduleAiCreditSubscriptionDowngrade.call(
       purchase: organization_ai_credit_purchase,
       new_price_id: determine_price_id
     )
     unless result.success?
       return render_general_errors([result.message || 'Unable to schedule plan change.'])
     end
     ```
  7. Render response: `render_one(organization_ai_credit_purchase.reload, Api::V1::OrganizationAiCreditPurchaseSerializer)`
  8. Same method-level rescue as preview action (A.2.2 step 8), with message: `['Unable to change subscription. Please try again.']`

- [ ] **A.3.2** **Critical constraint C3:** Verify the `items`, `proration_behavior`, and `proration_date` params are identical between the preview call (A.2.2 step 5) and the commit call (A.3.1 step 5). The preview uses `subscription_details: { items: ..., proration_behavior: ..., proration_date: ... }` and the commit uses flat params `{ items: ..., proration_behavior: ..., proration_date: ... }`. This is correct -- `Invoice.create_preview` nests under `subscription_details`, `Subscription.update` takes flat params.

### A.4 Controller: Remove portal actions

- [ ] **A.4.1** Remove `change_subscription_portal_session` action (lines 229-281)
- [ ] **A.4.2** Remove `update_payment_method_and_subscription_portal_session` action (lines 284-338)
- [ ] **A.4.3** Remove `continue_change_subscription_portal_session` action (lines 342-415)
- [ ] **A.4.4** Keep all private methods (`determine_price_id`, `organization_ai_credit_purchase_params`, `checkout_purchase_params`) -- they are still used by other actions

### A.5 New interactor: `ApplyAiCreditUpgrade`

**Read before working:** `cursor_rules/core_critical_rules.md` (rules 11, 12), `cursor_rules/backend_interactors_base.md`

**Structural analog:** `app/interactors/apply_ai_credit_purchase.rb` (91 lines)

- [ ] **A.5.1** Create `app/interactors/apply_ai_credit_upgrade.rb`. Follow the `ApplyAiCreditPurchase` transaction pattern exactly (structural manifest below), with EXPECTED DIFFERENCES noted.

**Structural manifest comparison (`ApplyAiCreditUpgrade` vs `ApplyAiCreditPurchase`):**

| Element | ApplyAiCreditPurchase (analog) | ApplyAiCreditUpgrade (new) | Match |
|---------|-------------------------------|---------------------------|-------|
| `include Interactor` | Line 10 | Yes | SAME |
| `def call` entry point | Line 12 | Yes | SAME |
| Context inputs | `context.invoice`, `context.kind`, `context.purchase` | `context.invoice`, `context.purchase` | DIFFERENT (no `kind` -- upgrades are always subscription) |
| Purchase lookup | `context.purchase \|\| find_by(...)` (line 31) | `context.purchase` only (always provided by webhook handler) | DIFFERENT (acceptable -- webhook handler always passes purchase) |
| Balance lookup | `organization.organization_ai_credit_balance` (line 41) | Same pattern | SAME |
| Missing balance guard | Logs error, `context.fail!` (lines 42-45) | Same pattern | SAME |
| Idempotency check | `return if stripe_invoice_id == invoice.id` (line 39) | Same check | SAME |
| Transaction block | `ApplicationRecord.transaction` (line 53) | Same | SAME |
| Purchase update fields | `subscription_status`, `subscription_current_period_start`, `subscription_current_period_end`, `stripe_invoice_id` (lines 54-59) | `stripe_invoice_id` ONLY | DIFFERENT (customer.subscription.updated handler already updates status/period fields) |
| Update return check | `fail_with_record_invalid` (line 60) | Same | SAME |
| `finalize_stripe_payment` call | Line 62 | Same | SAME |
| `AiCreditBalanceTransaction` creation | `.new(...)` with `.save` (lines 64-71) | Same creation pattern | SAME |
| Credit amount source | `organization_ai_credit_purchase.subscription_credits_per_period` (line 70) | `credit_difference` (new_credits - old_credits, computed from invoice line items) | DIFFERENT (core difference -- grant delta, not full period amount) |
| entry_type | `:subscription_credit_pack_purchase_credit` (value 30) | Same | SAME |
| bucket | `:addon_subscription` (value 2) | Same | SAME |
| Description | `"Credit pack subscription grant for #{organization_ai_credit_purchase.stripe_price_lookup_key}"` (line 69) | `"Upgrade credit grant: #{old_lookup_key} -> #{new_lookup_key} (+#{credit_difference} credits)"` | DIFFERENT (distinguishes upgrade from renewal in ledger) |
| Transaction save check | `fail_with_record_invalid` (line 72) | Same | SAME |
| Balance notification reset | `sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false` (lines 74-78) | Same | SAME |
| Balance update check | `fail_with_record_invalid` (line 78) | Same | SAME |
| `fail_with_record_invalid` method | Private method, local (lines 82-90) | Private method, local (same pattern, different log prefix) | SAME shape, DIFFERENT prefix |
| Context output | `context.purchase = organization_ai_credit_purchase` | Same | SAME |

- [ ] **A.5.2** The interactor extracts old/new lookup keys from the invoice line items:
  ```ruby
  old_line = invoice.lines.data.find { |line| line.amount.negative? }
  new_line = invoice.lines.data.find { |line| line.amount.positive? }
  ```
  Confirmed against real Stripe invoice (`stripe-invoice-subscription-update-example.json`): line item at JSON line 65 has `amount: -83727` (old plan credit), line item at JSON line 181 has `amount: 156777` (new plan charge). Each line item has `price.lookup_key` nested under `price` (JSON lines 132, 243).

- [ ] **A.5.3** Compute credit difference:
  ```ruby
  old_credits = OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(old_lookup_key)
  new_credits = OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(new_lookup_key)
  credit_difference = new_credits - old_credits
  ```
  The `ai_credit_allocation_for_lookup_key` class method is at `organization_ai_credit_purchase.rb` lines 71-76. It returns `pack[:credits] || pack[:credits_per_period]`.

- [ ] **A.5.4** Guards (all with `context.fail!` and logging):
  - `old_line && new_line` must both exist
  - `old_credits && new_credits` must both be non-nil (recognized lookup keys)
  - `credit_difference.positive?` must be true

- [ ] **A.5.5** Variable naming: use `organization_ai_credit_purchase` (never `purchase`), `ai_credit_balance_transaction` (never `transaction`), `organization_ai_credit_balance` (or `balance` as established local shorthand within the method, matching the analog)

- [ ] **A.5.6** Single quotes for all string literals unless interpolation is needed (constraint C9)

### A.6 New interactor: `ScheduleAiCreditSubscriptionDowngrade`

**Read before working:** `cursor_rules/core_critical_rules.md` (rules 11, 12), `cursor_rules/backend_interactors_base.md`

**Structural analog:** `app/interactors/cancel_ai_credit_subscription.rb` (54 lines)

- [ ] **A.6.1** Create `app/interactors/schedule_ai_credit_subscription_downgrade.rb`

**Structural manifest comparison (`ScheduleAiCreditSubscriptionDowngrade` vs `CancelAiCreditSubscription`):**

| Element | CancelAiCreditSubscription (analog) | ScheduleAiCreditSubscriptionDowngrade (new) | Match |
|---------|-------------------------------------|---------------------------------------------|-------|
| `include Interactor` | Line 28 | Yes | SAME |
| Context inputs | `context.purchase` | `context.purchase`, `context.new_price_id` | DIFFERENT (needs target price) |
| Stripe-first pattern | Stripe call before local state (line 33) | Same -- Stripe calls first, no local state changes | SAME principle |
| Stripe API call | `Stripe::CancelCreditPackSubscription.cancel(...)` via service | Direct `Stripe::SubscriptionSchedule.create` + `.update` (multi-step, no service wrapper) | DIFFERENT mechanism |
| Local state update | `purchase.update(...)` (lines 35-42) | NONE -- webhook handler handles local state | DIFFERENT (spec mandates: interactor does NOT update purchase fields) |
| Error handling | `rescue Stripe::StripeError => e` (lines 45-52) | Same pattern | SAME |
| `context.fail!` on error | `error: :stripe_error, message: e.message` | Same | SAME |
| Variable naming | Uses `purchase` (line 31) -- violates rule | Must use `organization_ai_credit_purchase` | DIFFERENT (correct the violation) |

- [ ] **A.6.2** The interactor body:
  1. Extract `organization_ai_credit_purchase = context.purchase`
  2. Look up the current price ID from the subscription to build Phase 1:
     ```ruby
     stripe_subscription = Stripe::Subscription.retrieve(
       organization_ai_credit_purchase.stripe_subscription_id
     )
     current_price_id = stripe_subscription.items.data.first.price.id
     ```
  3. Create a schedule from the existing subscription:
     ```ruby
     schedule = Stripe::SubscriptionSchedule.create(
       from_subscription: organization_ai_credit_purchase.stripe_subscription_id
     )
     ```
  4. Update the schedule with two phases:
     ```ruby
     Stripe::SubscriptionSchedule.update(
       schedule.id,
       {
         end_behavior: 'release',
         phases: [
           {
             items: [{ price: current_price_id, quantity: 1 }],
             start_date: organization_ai_credit_purchase.subscription_current_period_start.to_i,
             end_date: organization_ai_credit_purchase.subscription_current_period_end.to_i
           },
           {
             items: [{ price: context.new_price_id, quantity: 1 }],
             iterations: 1
           }
         ]
       }
     )
     ```
  5. Set `context.purchase = organization_ai_credit_purchase`
  6. Method-level `rescue Stripe::StripeError => e` with `context.fail!(error: :stripe_error, message: e.message)`

- [ ] **A.6.3** Note: The existing `handle_subscription_schedule_downgrade` method in `stripe_webhook_handler_job.rb` (lines 342-401) will handle the `subscription_schedule.updated` event fired by this interactor. The `downgrade_detected?` method (lines 403-413) only recognizes ATS plan tiers, so Discord/engagement notifications will NOT fire for AI credit downgrades. This is explicitly out of scope per spec.

### A.7 Webhook handler: Modify `handle_subscription_credit_pack_invoice_paid`

**Read before working:** `cursor_rules/core_critical_rules.md`, `cursor_rules/backend_jobs_base.md`

**File:** `app/jobs/stripe_webhook_handler_job.rb`

- [ ] **A.7.1** Locate `handle_subscription_credit_pack_invoice_paid` (lines 472-490)
- [ ] **A.7.2** The `billing_reason` branch goes AFTER the payment-info stamp (line 487) and BEFORE the existing `ApplyAiCreditPurchase.call` (line 489). Replace line 489 with:
  ```ruby
  if invoice.billing_reason == 'subscription_update'
    ApplyAiCreditUpgrade.call(invoice: invoice, purchase: organization_ai_credit_purchase)
  else
    ApplyAiCreditPurchase.call(invoice: invoice, kind: :subscription, purchase: organization_ai_credit_purchase)
  end
  ```
- [ ] **A.7.3** **Guard ordering verification (known failure pattern #8):** The method's only guard is `raise CustomStripeSubscriptionMissingError if organization_ai_credit_purchase.nil?` at line 477. This fires BEFORE any branching and applies to ALL invoice types. Safe -- no guard between method entry and the new branch that would reject `subscription_update` invoices.
- [ ] **A.7.4** **Routing verification:** The `invoice.paid` dispatch at lines 283-284 routes to `handle_subscription_credit_pack_invoice_paid` based on `subscription_lookup_key` being a credit pack key. The `CustomStripeSubscriptionMissingError` guard at line 286 is in the ELSE branch (main-plan invoices) and does NOT affect credit-pack invoices.

---

## B. Frontend changes

### B.1 Mutation hooks: `useOrganizationAiCreditPurchase.ts`

**Read before working:** `cursor_rules/core_critical_rules.md` (rules 7, 9, 10)

**File:** `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`

- [ ] **B.1.1** Add TypeScript interfaces for the new mutations:
  ```typescript
  interface PreviewSubscriptionChangeParams {
    priceId: string;
  }

  interface PreviewSubscriptionChangeResponse {
    amountDue: number;
    currency: string;
    lines: Array<{
      amount: number;
      description: string;
      price: { lookupKey: string };
    }>;
    subscriptionItemId: string;
    currentPeriodEnd: number;
    defaultPaymentMethod: {
      brand: string;
      last4: string;
    } | null;
  }

  interface CommitSubscriptionChangeParams {
    priceId: string;
  }
  ```
  Note: Backend sends `snake_case` (`amount_due`, `lookup_key`, etc.) and the API layer transforms to `camelCase` automatically (rule 7).

- [ ] **B.1.2** Add `previewAiCreditSubscriptionChange` function and `usePreviewAiCreditSubscriptionChange` hook:
  ```typescript
  const previewAiCreditSubscriptionChange = async (
    params: PreviewSubscriptionChangeParams,
  ): Promise<PreviewSubscriptionChangeResponse> => {
    return await apiPost({
      path: "/ai_credit_purchases/preview_subscription_change",
      variables: params,
    });
  };

  function usePreviewAiCreditSubscriptionChange() {
    return useMutation(previewAiCreditSubscriptionChange);
  }
  ```

- [ ] **B.1.3** Add `commitAiCreditSubscriptionChange` function and `useCommitAiCreditSubscriptionChange` hook:
  ```typescript
  const commitAiCreditSubscriptionChange = async (
    params: CommitSubscriptionChangeParams,
  ) => {
    return await apiPost({
      path: "/ai_credit_purchases/commit_subscription_change",
      variables: params,
    });
  };

  function useCommitAiCreditSubscriptionChange() {
    const queryClient = useQueryClient();
    return useMutation(commitAiCreditSubscriptionChange, {
      onSuccess: () => {
        queryClient.invalidateQueries(["organizationAiCreditPurchase"]);
        queryClient.invalidateQueries(["organizationAiCreditBalance"]);
        queryClient.invalidateQueries(["aiCreditCustomerSubscription"]);
      },
    });
  }
  ```
  Note: The cancel hook invalidates `organizationAiCreditPurchase` + `organizationAiCreditBalance`. The new commit hook also invalidates `aiCreditCustomerSubscription` because the subscription's price changes on upgrade -- the customer_subscription query returns the live Stripe subscription data that the tier cards use to show which plan is current.

- [ ] **B.1.4** Remove the following (lines 35-91 in current file):
  - `changeAiCreditSubscriptionViaStripePortal` function (lines 35-48)
  - `useChangeAiCreditSubscriptionViaStripePortal` hook (lines 50-62)
  - `updateAiCreditSubscriptionWithPaymentMethod` function (lines 64-77)
  - `useUpdateAiCreditSubscriptionWithPaymentMethod` hook (lines 79-91)

- [ ] **B.1.5** Update the export block (lines 189-199): remove `useChangeAiCreditSubscriptionViaStripePortal` and `useUpdateAiCreditSubscriptionWithPaymentMethod`; add `usePreviewAiCreditSubscriptionChange` and `useCommitAiCreditSubscriptionChange`

### B.2 New modal: `UpdateAiCreditSubscriptionConfirmModal.tsx`

**Read before working:** `cursor_rules/core_critical_rules.md` (rules 2, 7, 9, 10), `cursor_rules/frontend_components_base.md`

**Visual reference:** `/Users/jessica/Projects/genuine-article-images/UpdateSubscriptionConfirmModal.tsx` -- visual design ONLY. All identifiers, imports, hooks, and data flow come from the codebase.

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx`

- [ ] **B.2.1** Create the file with these imports (all from codebase, not handoff):
  ```typescript
  import React, { useState } from "react";
  import styled from "@emotion/styled";
  import { css } from "@emotion/react";

  import CenterModal from "@ats/src/components/modals/CenterModal";
  import Button from "@ats/src/components/shared/Button";
  import Icon from "@ats/src/components/shared/Icon";
  ```
  Import paths verified: `CenterModal` at `@ats/src/components/modals/CenterModal` (cancel modal line 5), `Button` at `@ats/src/components/shared/Button` (cancel modal line 6), `Icon` at `@ats/src/components/shared/Icon` (used across account admin views, e.g. `AccountApiKeys.tsx` line 11).

- [ ] **B.2.2** Props interface matching the spec:
  ```typescript
  interface UpdateAiCreditSubscriptionConfirmModalProps {
    onCancel: () => void;
    onConfirm: () => void;
    isLoading: boolean;
    isDowngrade: boolean;
    newPlanName: string;
    newPlanCredits: number;
    newMonthlyPrice: string;
    startDate: string;
    paymentMethodLabel: string;
    amountDueToday: string;
    currentPlanName: string;
    creditForCurrentPlan: string;
    currentPlanCredits: number | null;
  }
  ```

- [ ] **B.2.3** Component body matching handoff visual layout:
  - `<CenterModal headerTitleText="Confirm your update" onCancel={onCancel}>` -- NO `hasUnsavedChanges` (constraint C6)
  - Plan name line: `{newPlanName} -- {newPlanCredits.toLocaleString()} credits / month`
  - Downgrade: scheduled note paragraph, pay row with monthly price and payment method
  - Upgrade: pay row, divider, expandable details section with toggle, due row, meta row with toggle link and payment method
  - Terms paragraph with links
  - Button row: `<Button onClick={onConfirm} loading={isLoading}>` with text `{isDowngrade ? "Confirm change" : "Confirm"}` + cancel button with `styleType="secondary"`
  - **Known failure pattern #11:** The confirm Button MUST have `loading={isLoading}` to prevent double-clicks. The cancel modal uses `disabled={isLoading}` (line 39); the Button component supports both `loading` and `disabled` props (Button/index.js lines 17-18). Use `loading` per the handoff design.
  - Local state: `const [showDetails, setShowDetails] = useState(false)` for the upgrade details toggle

- [ ] **B.2.4** Styled components using the `let Styled: any; Styled = {};` pattern per spec directive, with handoff visual styles. Every styled component name prefixed with `UpdateAiCreditSubscriptionConfirmModal_` in the label. Components from handoff:
  - `Styled.PlanName`
  - `Styled.ScheduledNote`
  - `Styled.PayRow`
  - `Styled.PayLabel`
  - `Styled.PayValue`
  - `Styled.Price`
  - `Styled.Card`
  - `Styled.Divider`
  - `Styled.Details`
  - `Styled.DetailRow`
  - `Styled.DetailDivider`
  - `Styled.DueRow`
  - `Styled.MetaRow`
  - `Styled.Toggle`
  - `Styled.Terms`
  - `Styled.ButtonContainer`

- [ ] **B.2.5** Theme color verification (rule 2): Check `app/javascript/ats/styles/theme.ts` lines 3-56 before using ANY color. The handoff uses: `t.color.gray[100]`, `t.color.gray[200]`, `t.color.gray[300]`, `t.color.gray[400]`, `t.color.gray[500]`, `t.color.gray[600]`, `t.color.gray[700]`, `t.color.black`. Verify each exists in the theme.

- [ ] **B.2.6** Emotion theme utilities (known failure pattern #1): `t.text.sm`, `t.text.md`, `t.text.bold`, `t.text.xs`, `t.mt(N)`, `t.my(N)`, `t.px(N)`, `t.py(N)`, `t.mr(N)`, `t.rounded.sm` are complete CSS declarations -- use standalone, NOT inside a property declaration.

- [ ] **B.2.7** **No conditional props on styled elements** (known failure pattern #12): The handoff uses `className="total"` and `className="num"` on elements, which is acceptable. No custom boolean props like `isKey`/`isActive` are passed to styled elements.

- [ ] **B.2.8** Export: `export default UpdateAiCreditSubscriptionConfirmModal;`

### B.3 Modify `AiCreditSubscription.tsx`

**Read before working:** `cursor_rules/core_critical_rules.md` (rules 7, 9, 10), `cursor_rules/frontend_components_base.md`

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`

- [ ] **B.3.1** Update imports (lines 6-14):
  - Remove: `useChangeAiCreditSubscriptionViaStripePortal` (line 8), `useUpdateAiCreditSubscriptionWithPaymentMethod` (line 9)
  - Add: `usePreviewAiCreditSubscriptionChange`, `useCommitAiCreditSubscriptionChange`
  - Add new import for the modal: `import UpdateAiCreditSubscriptionConfirmModal from "./UpdateAiCreditSubscriptionConfirmModal";`
  - Add imports from `@shared/lib/planHelpers`: `AI_CREDIT_PACK_DISPLAY_NAMES`, `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY`
  - Add import from `@shared/lib/time`: `prettyDate`

- [ ] **B.3.2** Replace mutation hook destructuring (lines 36-43):
  - Remove lines 36-43 (the two portal hooks)
  - Add:
    ```typescript
    const { mutate: previewSubscriptionChange, isLoading: isLoadingPreview } =
      usePreviewAiCreditSubscriptionChange();
    const { mutate: commitSubscriptionChange, isLoading: isCommittingChange } =
      useCommitAiCreditSubscriptionChange();
    ```

- [ ] **B.3.3** Remove `handleUpdateWithPaymentMethod` function (lines 82-117)

- [ ] **B.3.4** Remove `handleChangeSubscriptionViaStripePortal` function (lines 122-156)

- [ ] **B.3.5** Replace `handleSelectTier` (lines 158-170) with the new implementation per spec. Key implementation details:
  - `isDowngrade` computed as: `currentCredits != null && tier.credits < currentCredits`
  - Calls `previewSubscriptionChange({ priceId: tier.priceId }, { onSuccess, onError })`
  - `onSuccess`: formats amounts, opens `UpdateAiCreditSubscriptionConfirmModal` via `openModal`
  - Format `newMonthlyPrice` from `tier.priceDollars` (a number) to a string: `` `$${tier.priceDollars.toFixed(2)}` ``
  - Format `amountDueToday` and `creditForCurrentPlan` from cents to dollars using `formatCents` helper
  - `paymentMethodLabel`: capitalize brand first letter, append last4. Handle null with empty string
  - `startDate`: `previewData.currentPeriodEnd ? prettyDate(previewData.currentPeriodEnd) : ""`
  - `onConfirm` closure calls `commitSubscriptionChange({ priceId: tier.priceId }, { onSuccess, onError })`
  - Commit `onSuccess`: `removeModal()`, success toast with message dependent on `isDowngrade`
  - Commit `onError`: error toast with `error?.data?.errors?.general?.[0]` fallback pattern, `delay: 30000`
  - Preview `onError`: same error toast pattern
  - **Keep `redirectToStripe` function** (line 75-77) -- still used by `purchaseTopUpCheckoutSession` at line 231

- [ ] **B.3.6** Update loading state in tier cards (line 324):
  - Replace `isLoadingChangeSubscriptionViaStripePortal || isLoadingUpdateWithPaymentMethod` with `isLoadingPreview || isCommittingChange`
  - Keep `isSubscribing` in the expression

- [ ] **B.3.7** The `stripeDefaultPaymentMethodOnFile` check at line 159 inside `handleSelectTier` is removed as part of the function replacement. The check at line 250 inside `handleBuyPack` is NOT removed -- it's for the top-up flow.

### B.4 Modify `aiSubscriptionHelpers.ts`

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts`

- [ ] **B.4.1** Update `deriveTierButtonText` (lines 30-37) to add the "Downgrade" case:
  ```typescript
  export function deriveTierButtonText(
    isSubscribed: boolean,
    currentCredits: number | null,
    tierCredits: number,
  ): string {
    if (!isSubscribed) return "Subscribe";
    if (currentCredits != null && tierCredits > currentCredits) return "Upgrade";
    if (currentCredits != null && tierCredits < currentCredits) return "Downgrade";
    return "Change plan";
  }
  ```
  Current line 36 returns `"Upgrade"` or `"Change plan"`. The new version adds the `"Downgrade"` branch between them.

- [ ] **B.4.2** `deriveTierButtonType` (lines 44-49): No change needed. The fallthrough already returns `"secondary"` for `"Downgrade"`. The spec says this change is optional.

---

## C. Test plan

### C.1 Remove existing portal spec

- [ ] **C.1.1** Remove `spec/controllers/api/v1/organization_ai_credit_purchases_change_subscription_spec.rb` entirely (193 lines). This spec tests `change_subscription_portal_session` which is being deleted. Verified: this is the only spec file covering the removed actions.

### C.2 New controller spec: `preview_subscription_change` and `commit_subscription_change`

**Read before working:** `cursor_rules/backend_rspec_base.md`

- [ ] **C.2.1** Create `spec/controllers/api/v1/organization_ai_credit_purchases_subscription_change_spec.rb`
- [ ] **C.2.2** Follow the pattern from `organization_ai_credit_purchases_change_subscription_spec.rb` for test setup:
  - Use `create_credit_test_organization(stripe_active: true)` with `stripe_customer_id`
  - Create `OrganizationAiCreditPurchase` with `kind: :subscription`, `subscription_status: :active`, `stripe_subscription_id`, `stripe_price_lookup_key`, `subscription_credits_per_period`, `subscription_current_period_start`, `subscription_current_period_end`
  - Stub Pundit authorization and current_user/current_organization resolution (same pattern as existing spec lines 19-73)
  - Double all Stripe API calls

- [ ] **C.2.3** `preview_subscription_change` test cases:
  - Success: returns preview JSON with correct shape (amountDue, currency, lines, subscriptionItemId, currentPeriodEnd, defaultPaymentMethod)
  - No active subscription: renders error
  - Non-admin user: returns 403 (Pundit)
  - Stripe error: renders error message via `render_general_errors`
  - Missing price_id param: raises StandardError

- [ ] **C.2.4** `commit_subscription_change` test cases:
  - Upgrade success: stubs `Stripe::Price.retrieve` returning a price with higher-credit lookup key, stubs `Stripe::Subscription.update`, verifies it was called with correct params, returns updated purchase
  - Downgrade success: stubs `Stripe::Price.retrieve` returning a price with lower-credit lookup key, stubs `ScheduleAiCreditSubscriptionDowngrade.call`, verifies it was called, returns updated purchase
  - No active subscription: renders error
  - Non-admin user: returns 403
  - Stripe error: renders error message
  - Downgrade interactor failure: renders error message from context

### C.3 New interactor spec: `ApplyAiCreditUpgrade`

**Read before working:** `cursor_rules/backend_rspec_base.md`

- [ ] **C.3.1** Create `spec/interactors/apply_ai_credit_upgrade_spec.rb`
- [ ] **C.3.2** Test cases:
  - Grants correct credit difference (e.g., 1000 - 500 = 500): verify `AiCreditBalanceTransaction` created with correct `amount`, `entry_type`, `bucket`, `description`
  - Idempotent: calling with same `invoice.id` twice does not double-grant
  - Missing balance: context fails with `:missing_balance`
  - Unrecognized lookup keys: context fails with `:unrecognized_lookup_key`
  - Non-positive credit difference: context fails with `:invalid_credit_difference`
  - Missing line items (no negative or no positive line): context fails with `:invalid_invoice_lines`
  - Resets notification flags on balance (`sent_low_notification_since_increase`, `sent_zero_notification_since_increase`)
  - Stamps `stripe_invoice_id` on purchase
  - Calls `finalize_stripe_payment` on purchase

### C.4 New interactor spec: `ScheduleAiCreditSubscriptionDowngrade`

- [ ] **C.4.1** Create `spec/interactors/schedule_ai_credit_subscription_downgrade_spec.rb`
- [ ] **C.4.2** Test cases:
  - Success: stubs `Stripe::SubscriptionSchedule.create` and `.update`, verifies called with correct params (phases, end_behavior)
  - Stripe error: context fails with `:stripe_error`, local state untouched

### C.5 Webhook handler spec addition

**Existing spec file:** `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`

- [ ] **C.5.1** Add test cases to `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` for the `billing_reason` branching in `handle_subscription_credit_pack_invoice_paid`:
  - `billing_reason: 'subscription_update'` routes to `ApplyAiCreditUpgrade.call` (not `ApplyAiCreditPurchase.call`)
  - `billing_reason: 'subscription_cycle'` routes to `ApplyAiCreditPurchase.call` (existing behavior preserved)
  - `billing_reason: 'subscription_create'` routes to `ApplyAiCreditPurchase.call` (existing behavior preserved)

---

## D. Portal flow removal verification

- [ ] **D.1** After all changes, grep the entire codebase for ALL removed identifiers to confirm zero remaining references:
  - `change_subscription_portal_session`
  - `update_payment_method_and_subscription_portal_session`
  - `continue_change_subscription_portal_session`
  - `changeAiCreditSubscriptionViaStripePortal`
  - `useChangeAiCreditSubscriptionViaStripePortal`
  - `updateAiCreditSubscriptionWithPaymentMethod`
  - `useUpdateAiCreditSubscriptionWithPaymentMethod`
  - `handleChangeSubscriptionViaStripePortal`
  - `handleUpdateWithPaymentMethod`

- [ ] **D.2** Note: The billing controller (`app/controllers/api/v1/billing_controller.rb`) has its OWN `change_subscription_portal_session` (line 268), `update_payment_method_and_subscription_portal_session` (line 331), and `continue_change_subscription_portal_session` (line 385). These are for the ATS plan billing, NOT AI credit billing, and are NOT removed. The grep results will show these -- they are expected.

- [ ] **D.3** Note: The `useBilling.ts` hook file (lines 56, 71) has its own portal functions for ATS billing. These are also NOT removed.

- [ ] **D.4** The grep should show ZERO results from:
  - `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`
  - `config/routes.rb` lines 190-201 (the AI credit purchases routes)
  - `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`
  - `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`
  - `spec/controllers/api/v1/organization_ai_credit_purchases_change_subscription_spec.rb` (file should not exist)

---

## E. Validation and constraints checklist

- [ ] **E.1** Constraint C1: Credits granted on `invoice.paid` only -- `ApplyAiCreditUpgrade` is called only from `handle_subscription_credit_pack_invoice_paid`, which is only called from the `invoice.paid` webhook handler. The `customer.subscription.updated` handler (lines 111-165) does NOT grant credits.
- [ ] **E.2** Constraint C2: `billing_reason` routing is correct for all three values (`subscription_update`, `subscription_cycle`, `subscription_create`)
- [ ] **E.3** Constraint C3: Preview and commit params match exactly (verified in A.3.2)
- [ ] **E.4** Constraint C4: Subscription ID stays the same -- `Stripe::Subscription.update` modifies in place
- [ ] **E.5** Constraint C5: Handoff file is visual reference only -- all identifiers from codebase
- [ ] **E.6** Constraint C6: No `hasUnsavedChanges` on the modal
- [ ] **E.7** Constraint C7: Variable naming rules followed (full model names)
- [ ] **E.8** Constraint C8: No begin blocks in controllers
- [ ] **E.9** Constraint C9: Single quotes in Ruby
- [ ] **E.10** Constraint C10: `determine_price_id` reused from existing private method

---

## F. Risks and open questions

### F.1 `proration_date` accuracy
The spec sets `proration_date: organization_ai_credit_purchase.subscription_current_period_start.to_i` to achieve full-price math (no time-prorating). This should produce `new_price - old_price` as the amount. If Stripe computes differently, the preview will show the actual Stripe amount (which is correct per approved decision #2: "the preview is the authoritative source"). The goal is full monthly price difference; the exact param may need adjustment. Test in Stripe test mode before deploying.

### F.2 SubscriptionSchedule for existing scheduled subscriptions
If the subscription already has a pending SubscriptionSchedule (e.g., from a previous downgrade), `Stripe::SubscriptionSchedule.create(from_subscription: ...)` may fail. The spec notes this: "the create call may need to update the existing schedule instead." The interactor's `rescue Stripe::StripeError` will catch this, and the user will see an error toast. A follow-up enhancement could detect existing schedules and update them.

### F.3 `priceDollars` formatting
`AiCreditTier.priceDollars` is a `number` (e.g. 39, 129, 249) computed as `price.unitAmount / 100` in `planHelpers.ts` line 118. The modal's `newMonthlyPrice` prop expects a `string` (e.g. "$129.00"). The `handleSelectTier` code must format it: `` `$${tier.priceDollars.toFixed(2)}` ``. This matches how the existing tier cards display the price (e.g. `${tier.priceDollars}` in `AiSubscriptionTierCard.tsx` line 58).

### F.4 `prettyDate` returns null for null input
`prettyDate` (time.ts line 43-47) returns `null` for undefined/null input. The `startDate` prop on the modal should handle this: `previewData.currentPeriodEnd ? prettyDate(previewData.currentPeriodEnd) : ""`. Since `currentPeriodEnd` comes from the live Stripe subscription, it should always be present for active subscriptions.

---

## G. Estimated scope

| Area | Effort |
|------|--------|
| Routes (A.1) | Small -- 5 lines changed |
| Controller actions (A.2, A.3, A.4) | Medium -- ~100 lines added, ~180 lines removed |
| ApplyAiCreditUpgrade interactor (A.5) | Medium -- ~90 lines, closely follows analog |
| ScheduleAiCreditSubscriptionDowngrade interactor (A.6) | Small -- ~40 lines |
| Webhook handler modification (A.7) | Small -- 5 lines changed |
| Modal component (B.2) | Medium-Large -- ~365 lines (matching handoff visual design with styled components) |
| Mutation hooks (B.1) | Small -- ~50 lines added, ~60 lines removed |
| AiCreditSubscription.tsx (B.3) | Medium -- ~70 lines replaced, ~80 lines removed |
| aiSubscriptionHelpers.ts (B.4) | Small -- 1 line added |
| Test specs (C.1-C.5) | Medium -- ~3 new spec files, 1 removed |
| Portal removal verification (D) | Small -- grep sweep |

**Total estimated new code:** ~700 lines (including tests)
**Total estimated removed code:** ~400 lines (portal actions, portal hooks, portal spec)
**Net change:** ~+300 lines

---

## H. cursor_rules files to read per step

| Step | cursor_rules files |
|------|-------------------|
| A.1 (Routes) | `core_critical_rules.md` (rule 4: PUT for updates) |
| A.2-A.4 (Controller) | `core_critical_rules.md` (rules 1, 3, 7, 8, 11, 12), `backend_controllers_base.md` |
| A.5-A.6 (Interactors) | `core_critical_rules.md` (rules 11, 12), `backend_interactors_base.md` |
| A.7 (Webhook handler) | `core_critical_rules.md`, `backend_jobs_base.md` |
| B.1 (Hooks) | `core_critical_rules.md` (rules 7, 9, 10) |
| B.2 (Modal) | `core_critical_rules.md` (rules 2, 7, 9, 10), `frontend_components_base.md` |
| B.3 (AiCreditSubscription) | `core_critical_rules.md` (rules 7, 9, 10), `frontend_components_base.md` |
| B.4 (Helpers) | `core_critical_rules.md` |
| C.1-C.5 (Tests) | `core_critical_rules.md`, `backend_rspec_base.md` |
