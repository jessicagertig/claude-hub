# QA Layer 2: Code Correctness Review

Reviewed cold — no spec, no plan, no prior review context. Judged purely on correctness, safety, and convention adherence.

---

## File-by-file review

### `app/interactors/apply_ai_credit_upgrade.rb` (NEW)

**Purpose:** Grants the credit DIFFERENCE between old and new subscription plans when an upgrade proration invoice is paid.

**Correctness:**
- Idempotency check (line 38) is sound: compares `organization_ai_credit_purchase.stripe_invoice_id` against `invoice.id`. First invocation stamps the invoice ID on line 68-69; repeat deliveries short-circuit.
- Line item extraction (lines 41-42) uses `amount.negative?` / `amount.positive?` to distinguish old and new lines. This assumes exactly two lines with opposite signs. A zero-amount line (e.g., a $0 free-tier line) would match neither predicate — but that scenario would mean upgrading from/to a free tier, which is not an AI credit subscription scenario (all subscription tiers have positive prices).
- Credit difference validation (line 62) correctly guards against non-positive differences.
- Transaction block (lines 67-90) groups the invoice stamp, finalize, ledger row, and notification reset atomically.
- Uses `fail_with_record_invalid` helper consistently for all save failures.

**Convention compliance:**
- Variable naming follows model-name convention: `organization_ai_credit_purchase`, `ai_credit_balance_transaction`.
- Single quotes used throughout.
- `ap errors` on line 99 follows the `ap` convention.
- No begin blocks.

**No issues found.**

---

### `app/interactors/schedule_ai_credit_subscription_downgrade.rb` (NEW)

**Purpose:** Creates a Stripe SubscriptionSchedule that changes the subscription price at the end of the current billing period.

**Correctness:**
- `end_behavior: 'release'` (line 35) is correct: after the schedule's second phase completes, the subscription is released from the schedule and continues at the new price indefinitely.
- Phase 1 uses `subscription_current_period_start` / `subscription_current_period_end` from the local purchase record. If these are stale (e.g., webhook hasn't updated them yet), the schedule would have wrong dates. However, the controller that calls this interactor first calls `Stripe::Subscription.retrieve` and the interactor also retrieves the subscription (line 23-24), so a freshness issue on local fields is a minor concern but not a bug — Stripe validates the phase dates against the actual subscription period.
- The interactor does NOT update local state. Per the docstring, the `subscription_schedule.updated` webhook handles local reconciliation. This is the Stripe-first pattern.

**Convention compliance:**
- Variable naming: `organization_ai_credit_purchase` is correct.
- Rescue block uses `Stripe::StripeError` (specific class).
- Single quotes, no begin blocks.

**No issues found.**

---

### `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (MODIFIED)

**Purpose:** API controller for AI credit subscription and one-off purchase operations.

#### `checkout` action (lines 15-66)

**BLOCKER: Two method calls to nonexistent methods.**

- Line 19: `OrganizationAiCreditPurchase.subscription_key?(lookup_key)` — this method does not exist on the model. The model defines `ai_credit_subscription_plan_lookup_key?`.
- Line 31: `OrganizationAiCreditPurchase.credit_amount_for_key(lookup_key)` — this method does not exist on the model. The model defines `ai_credit_allocation_for_lookup_key`.

Both will raise `NoMethodError` at runtime. The `checkout` action is completely broken — no new subscription can be created.

#### `preview_subscription_change` action (lines 228-287)

- Line 258: `proration_date: organization_ai_credit_purchase.subscription_current_period_start.to_i` — this mirrors the BillingController analog pattern.
- Line 261-266: Payment method retrieval falls back to the customer's invoice settings default. If neither exists, `default_payment_method` is nil, and the frontend receives `null` for the payment method. The modal handles this gracefully (empty string for `paymentMethodLabel`).
- The action correctly uses `authorize :billing, :change_subscription?`.

**No issues beyond the general `determine_price_id` concerns noted below.**

#### `commit_subscription_change` action (lines 289-353)

- **Convention violation on line 347:** `organization_ai_credit_purchase.reload` — `cursor_rules/backend/_base.md` rule 8 prohibits `.reload` in application code. The BillingController analog does NOT use `.reload` in its subscription change actions. The `.reload` is used because the Stripe `Subscription.update` call triggers a webhook that may update the purchase row concurrently. The correct fix is to fetch the updated fields from the Stripe API response rather than reloading.
- The downgrade path (lines 322-329) calls `ScheduleAiCreditSubscriptionDowngrade`, and the upgrade path (lines 330-344) calls `Stripe::Subscription.update` directly. The upgrade path does not use an interactor — it inlines the Stripe call in the controller. The cancel action (lines 193-214) delegates to `CancelAiCreditSubscription` interactor. This is an asymmetry: cancel and downgrade have interactors, upgrade does not.
- Line 307: `Stripe::Price.retrieve(determine_price_id)` makes a Stripe API call to get the lookup key. This is necessary because `determine_price_id` returns a raw Stripe price ID, not a lookup key.

#### `determine_price_id` (lines 381-387)

- The else-branch raises `StandardError` with `'Price ID is missing.'`. The BillingController analog falls back to a default price lookup key. The raise is correct for AI credits (no single default tier exists), but `StandardError` is generic. A more specific error message would help debugging, though the controller's rescue blocks catch `StandardError` and render appropriate errors. Acceptable.

#### `customer_subscription` (lines 358-370)

- Line 367: The `rescue StandardError` block does not call `ap e` after `Rails.logger.error(e)`. Other rescue blocks in this controller consistently use both. Minor inconsistency.

#### General controller observations

- Authorization uses `BillingPolicy` for subscription-changing actions (`change_subscription?`, `cancel_subscription?`, `create_subscription?`) and `OrganizationAiCreditPurchasePolicy` for read-only actions (`show?`, `prices?`). This is consistent with the BillingController analog.
- Two params methods (`organization_ai_credit_purchase_params` and `checkout_purchase_params`) — rule 5 says one params method per controller. However, the comment explains this mirrors the `BoardWwrListingsController` which also has two (one wrapped, one bare). Since this is a structural analog match, the deviation is justified.

---

### `app/jobs/stripe_webhook_handler_job.rb` (MODIFIED)

#### `handle_subscription_credit_pack_invoice_paid` (lines 472-494)

- Lines 479-487: Updates `stripe_amount`, `currency`, `stripe_invoice_item_id` on the purchase before branching on `billing_reason`. For upgrade proration invoices (`subscription_update`), `stripe_amount` correctly reflects the prorated amount paid, not the full plan price.
- Line 490: `ApplyAiCreditUpgrade.call(invoice: invoice, purchase: organization_ai_credit_purchase)` — correctly passes both the invoice and the purchase to the interactor.
- Line 492: `ApplyAiCreditPurchase.call(invoice: invoice, kind: :subscription, purchase: organization_ai_credit_purchase)` — the non-upgrade path (regular renewal or first invoice) delegates to the existing interactor.
- The `billing_reason == 'subscription_update'` check is the correct Stripe API value for proration invoices triggered by plan changes.

#### `handle_subscription_schedule_downgrade` (lines 342-401)

- Lines 360-376: Handles both `items` and `plans` API shapes for backward compatibility across Stripe API versions.
- The `downgrade_detected?` method (lines 403-414) uses a `plan_tiers` array with main-plan tier names (`free`, `starter`, `growth`, `scale`, `enterprise`). AI credit subscription lookup keys contain strings like `plato_ai_credit_subscription_small` — none of these contain any of the tier names in `plan_tiers`. This means `current_tier` and `next_tier` both default to `0`, and `downgrade_detected?` returns `false`. The Discord notification and engagement report jobs will NEVER fire for AI credit subscription downgrades. However, this may be intentional — the `handle_subscription_schedule_downgrade` was written for main-plan downgrades, and AI credit downgrades might not need notifications. Flagging as informational.

#### `customer.subscription.updated` handler (lines 111-165)

- Lines 125-148: The AI credit branch correctly uses `ai_credit_subscription_plan_lookup_key?` to detect credit-pack subscription events and updates the local purchase row with the new lookup key, credits, status, and period dates.
- Line 149: The main-plan branch guards with `object.id == organization&.stripe_subscription_id` to prevent credit-pack events from clobbering main-plan fields.

#### `customer.subscription.deleted` handler (lines 167-213)

- Lines 180-200: The AI credit branch correctly finds the purchase by `stripe_subscription_id` and updates status to `canceled`. It does NOT call `sync_with_stripe` or fire notification/engagement-report jobs — matching the comment's explanation.

#### `subscription_schedule.updated/created` handler (lines 326-328)

- Delegates to `handle_subscription_schedule_downgrade`. As noted above, the downgrade detection logic won't trigger for AI credit plans.

**No bugs found in the webhook handler modifications.**

---

### `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` (MODIFIED)

- `usePreviewAiCreditSubscriptionChange` (lines 68-70): Returns a mutation, not a query. Correct for a POST action that computes a preview.
- `useCommitAiCreditSubscriptionChange` (lines 81-90): Invalidates `organizationAiCreditPurchase`, `organizationAiCreditBalance`, and `aiCreditCustomerSubscription` queries on success. This is thorough — all three caches need refreshing after a plan change.
- `previewAiCreditSubscriptionChange` (line 64-65): Posts `params` directly (unwrapped). The controller's `determine_price_id` reads `params[:price_id]`, so `{ priceId: string }` will be snake-cased to `price_id` by the API layer. Correct.
- `commitAiCreditSubscriptionChange` (line 75-76): Same pattern. Correct.

**No issues found.**

---

### `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` (MODIFIED)

#### `handleSelectTier` (lines 78-150)

- Line 79: `const isDowngrade = currentCredits != null && tier.credits < currentCredits` — uses `!=` (loose inequality). This correctly handles both `null` and `undefined`. Consistent with `deriveTierButtonText` in the helper file which uses the same pattern.
- Line 129: `isLoading={isCommittingChange}` — this passes the committing mutation's loading state to the modal. However, the modal is opened by the preview mutation's `onSuccess`, at which point `isCommittingChange` is `false`. When the user clicks "Confirm" inside the modal, `commitSubscriptionChange` fires and `isCommittingChange` becomes `true`. But the modal was rendered with a captured closure — `isCommittingChange` won't update inside the already-rendered modal because React closures capture the value at render time. The modal's `isLoading` prop will always be `false` because the modal was rendered by `openModal` with `isCommittingChange: false`, and `openModal` does not re-render the modal when the parent's state changes. **The confirm button will never show a loading state.**
- Line 107: `removeModal()` is called immediately before `commitSubscriptionChange` — this dismisses the modal before the API call starts, so the loading state issue above is mitigated by the fact that the modal is already gone. However, this means there's no visual feedback that the commit is in progress. The toast on success/error provides eventual feedback.

#### `handleCancelClick` (lines 248-269)

- Line 265: `isLoading={isCanceling}` — same closure issue. The modal is rendered once by `openModal`, and `isCanceling` won't update. However, line 253 also calls `removeModal()` before the mutation, so the modal is dismissed before the loading state would matter.

#### Tier card rendering (lines 290-309)

- Line 291: `const isCurrent = currentSubscription?.plan?.id === tier.priceId` — accesses `currentSubscription.plan.id`. In Stripe subscription objects, the `plan` field is deprecated in favor of `items.data[0].price`. Line 56 already extracts `currentPriceObject` via `items.data[0].price`. The `plan.id` on line 291 is a different object — `plan` is the legacy plan object. If Stripe stops including the deprecated `plan` field, `isCurrent` will always be `false` and the "Current plan" badge won't display. The fix would be to compare `currentPlanLookupKey === tier.lookupKey` instead.

**One correctness concern (stale closure for isLoading) and one fragility concern (deprecated plan.id).**

---

### `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx` (NEW)

**Purpose:** Confirmation modal for subscription upgrades and downgrades.

**Correctness:**
- The modal correctly branches on `isDowngrade` to show different content: downgrades show a scheduling notice and hide the proration details; upgrades show the proration breakdown with expandable details.
- `newPlanCredits.toLocaleString()` correctly formats credit counts with thousands separators.
- The `showDetails` toggle (lines 44, 105) uses a `useState` boolean, toggled via a styled button. Clean pattern.

**Convention compliance:**
- Uses `CenterModal` with `headerTitleText` — matches other confirm modals.
- The Button component does NOT receive `disabled` prop. The `CancelAiCreditSubscriptionConfirmModal` analog passes `disabled={isLoading}` to its confirm button (the "Yes, cancel" button). This modal passes `loading={isLoading}` but not `disabled`. If the `Button` component doesn't internally disable when `loading` is true, double-clicks could fire multiple commits. **Check whether Button disables itself when loading.**
- The other confirm modals (`CancelAiCreditSubscriptionConfirmModal`, `PurchaseAiCreditTopUpConfirmModal`) use `Styled.Body` + `Styled.ButtonRow` for layout. This modal uses `Styled.ButtonContainer` and has no `Styled.Body` wrapper — the content is directly inside `CenterModal`. This is a structural pattern deviation from the analogs, though it's a minor layout difference.

---

### `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts` (MODIFIED)

- `splitTiers` (lines 19-28): Correctly splits prices into subscription and one-off arrays.
- `deriveTierButtonText` (lines 30-39): Returns "Subscribe" / "Upgrade" / "Downgrade" / "Change plan" based on credit comparison. The "Change plan" fallback handles the `currentCredits === tierCredits` case (same plan).
- `deriveTierButtonType` (lines 46-51): Returns "primary" for "Upgrade"/"Subscribe", "secondary" for everything else. This means the "Downgrade" button gets `secondary` style, which is a reasonable UX choice.

**No issues found.**

---

## Analog structural matching

### ApplyAiCreditUpgrade vs. ApplyAiCreditPurchase (the credit-granting analogs)

| Aspect | ApplyAiCreditPurchase | ApplyAiCreditUpgrade | Match? |
|---|---|---|---|
| Idempotency mechanism | `stripe_subscription_id` lookup | `stripe_invoice_id` comparison | DIFFERENT — justified (upgrade invoices are per-event, not per-subscription) |
| Balance check | Yes (`context.fail!(:missing_balance)`) | Yes (`context.fail!(:missing_balance)`) | SAME |
| Calls `finalize_stripe_payment` | Yes | Yes | SAME |
| Creates `AiCreditBalanceTransaction` | Yes | Yes | SAME |
| Entry type | `subscription_credit_pack_purchase_credit` | `subscription_credit_pack_purchase_credit` | SAME |
| Bucket | `addon_subscription` | `addon_subscription` | SAME |
| Amount source | `subscription_credits_per_period` | `credit_difference` (new - old) | DIFFERENT — justified (upgrade grants differential) |
| Resets notification flags | Yes | Yes | SAME |
| WebSocket broadcast + growl | Yes (via `grant_credits`) | No | DIFFERENT — see finding |
| Error handling pattern | `fail_with_record_invalid` | `fail_with_record_invalid` | SAME |

**Structural deviation:** `ApplyAiCreditPurchase` (for first invoice / renewal) calls `grant_credits` on the model, which broadcasts a WebSocket event and shows a growl notification. `ApplyAiCreditUpgrade` does NOT broadcast or notify. After an upgrade, the user receives no in-app confirmation that their additional credits were granted. This may be intentional (the UI flow already shows a success toast), but it's a behavioral difference from the analog.

### ScheduleAiCreditSubscriptionDowngrade vs. CancelAiCreditSubscription

| Aspect | CancelAiCreditSubscription | ScheduleAiCreditSubscriptionDowngrade | Match? |
|---|---|---|---|
| Stripe call first | Yes | Yes | SAME |
| Local state update | Yes (subscription_status, canceled_at) | No (relies on webhook) | DIFFERENT — see finding |
| Rescue Stripe errors | Yes (via interactor context.fail!) | Yes | SAME |
| Error reporting | `context.fail!(:stripe_error)` | `context.fail!(:stripe_error)` | SAME |

**Structural deviation:** `CancelAiCreditSubscription` updates local state (subscription_status, subscription_canceled_at) immediately after the Stripe call succeeds. `ScheduleAiCreditSubscriptionDowngrade` does NOT update local state — it relies entirely on the `subscription_schedule.updated` webhook. This means the UI won't reflect the pending downgrade until the webhook fires and updates the purchase row. If the webhook is delayed, the user sees no indication that their downgrade was scheduled. The `commit_subscription_change` controller renders `render_one(organization_ai_credit_purchase.reload, ...)`, but since no local state was changed, the response will show the old plan data.

### commit_subscription_change vs. BillingController change_subscription

| Aspect | BillingController | OrganizationAiCreditPurchasesController | Match? |
|---|---|---|---|
| Proration behavior | `always_invoice` | `always_invoice` | SAME |
| Proration date | `subscription_current_period_start.to_i` | `subscription_current_period_start.to_i` | SAME |
| Uses `.reload` | No | Yes (line 347) | DIFFERENT — convention violation |
| Rescue pattern | `Stripe::StripeError` with Sentry | `Stripe::StripeError` with Sentry | SAME |

### UpdateAiCreditSubscriptionConfirmModal vs. CancelAiCreditSubscriptionConfirmModal / PurchaseAiCreditTopUpConfirmModal

| Aspect | Cancel/Purchase Modals | Update Modal | Match? |
|---|---|---|---|
| Uses CenterModal | Yes | Yes | SAME |
| Styled.Body wrapper | Yes | No (content directly in CenterModal) | DIFFERENT |
| Styled.ButtonRow | Yes (flex-end, gap) | No (uses Styled.ButtonContainer with mr pattern) | DIFFERENT |
| disabled prop on confirm button | Yes (cancel modal) | No | DIFFERENT |
| Accepts isLoading | Yes | Yes | SAME |

---

## Findings

### BLOCKER-1: `checkout` action calls nonexistent model methods

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:19,31`

**Evidence:**
- Line 19: `OrganizationAiCreditPurchase.subscription_key?(lookup_key)` — method does not exist
- Line 31: `OrganizationAiCreditPurchase.credit_amount_for_key(lookup_key)` — method does not exist

The model defines `ai_credit_subscription_plan_lookup_key?` and `ai_credit_allocation_for_lookup_key` respectively. Both calls will raise `NoMethodError` at runtime. The entire `checkout` action — the path for creating a new AI credit subscription — is broken.

**Fix:** Change line 19 to `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(lookup_key)` and line 31 to `OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(lookup_key)`.

---

### HIGH-1: `.reload` in application code violates convention

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:347`

**Evidence:** `render_one(organization_ai_credit_purchase.reload, Api::V1::OrganizationAiCreditPurchaseSerializer)`

`cursor_rules/backend/_base.md` rule 8: "Do not use reload in application code." The BillingController analog does not use `.reload`. The `.reload` is used because Stripe's `Subscription.update` triggers a webhook that may concurrently update the purchase row, but the convention says to fix the data flow instead.

**Fix:** For the upgrade path, read the updated fields from the Stripe API response and update the local record explicitly before rendering. For the downgrade path, the interactor should update local state (analogous to `CancelAiCreditSubscription`) before returning.

---

### HIGH-2: Downgrade interactor does not update local state (analog structural mismatch)

**File:** `app/interactors/schedule_ai_credit_subscription_downgrade.rb`

**Evidence:** The analog `CancelAiCreditSubscription` updates `subscription_status` and `subscription_canceled_at` immediately after the Stripe call. `ScheduleAiCreditSubscriptionDowngrade` updates nothing locally — it relies entirely on the `subscription_schedule.updated` webhook. This means:

1. The controller's `render_one(organization_ai_credit_purchase.reload, ...)` returns stale data (the old plan, no indication of pending downgrade).
2. If the webhook is delayed, the user has no indication the downgrade was scheduled.
3. The serializer does not expose a `pending_downgrade` or `scheduled_change` field, so even after the webhook fires, the frontend has no way to know a downgrade is pending until the period actually ends.

The cancel analog's pattern of updating local state immediately is the convention for Stripe-first operations in this codebase.

---

### HIGH-3: `isCurrent` check uses deprecated Stripe `plan.id` field

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:291`

**Evidence:** `const isCurrent = currentSubscription?.plan?.id === tier.priceId`

The `plan` field on Stripe subscriptions is deprecated. The same file already extracts the price via the non-deprecated path on line 56: `currentSubscription.items.data[0].price`. If Stripe removes the `plan` field, `isCurrent` will always be `false` and the "Current plan" badge will never display.

**Fix:** Use `currentPlanLookupKey === tier.lookupKey` or `currentPriceObject?.id === tier.priceId` instead.

---

### MED-1: No WebSocket broadcast or growl notification for upgrade credit grants

**File:** `app/interactors/apply_ai_credit_upgrade.rb`

**Evidence:** The analog `ApplyAiCreditPurchase` calls `grant_credits` on the model, which broadcasts a WebSocket event (`AI_CREDIT_TOP_UP_COMPLETE`) and shows a growl notification to the user. `ApplyAiCreditUpgrade` creates the ledger row directly without any broadcast or notification. After an upgrade, the user's credit balance increases silently with no in-app confirmation beyond the toast shown by the frontend mutation's `onSuccess`.

This may be intentional (the upgrade flow's success toast provides feedback), but it's a behavioral divergence from the analog. Other users in the org will not see the credit increase until they refresh.

---

### MED-2: Confirm button missing `disabled` prop (analog deviation)

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx:122`

**Evidence:** `<Button onClick={onConfirm} loading={isLoading}>` — the confirm button passes `loading` but not `disabled={isLoading}`. The `CancelAiCreditSubscriptionConfirmModal` analog passes both `loading` and `disabled` to its confirm button. If the `Button` component does not internally disable itself when `loading` is true, rapid double-clicks could trigger multiple subscription commits.

Note: This is partially mitigated by the fact that `removeModal()` is called before `commitSubscriptionChange` in the parent — the modal is dismissed immediately. But the `isLoading` prop is still passed, suggesting the intent was to show loading state without dismissing.

---

### MED-3: `customer_subscription` rescue block inconsistent with other actions

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:366-369`

**Evidence:** The rescue block calls `Sentry.capture_exception(e)` and `Rails.logger.error(e)` but does NOT call `ap e`. Every other rescue block in this controller (checkout, cancel, prices, preview, commit) uses `ap e` after logging. Missing `ap e` means this error won't appear in the console during development.

---

### LOW-1: `downgrade_detected?` does not recognize AI credit subscription lookup keys

**File:** `app/jobs/stripe_webhook_handler_job.rb:403-414`

**Evidence:** The `plan_tiers` array contains `%w[free starter growth scale enterprise]`. AI credit subscription lookup keys are like `plato_ai_credit_subscription_small`. None of these contain any tier name from `plan_tiers`, so `downgrade_detected?` will always return `false` for AI credit downgrades. `Discord::NotifyDowngradeScheduledJob` and `EngagementReport::GeneratorJob` will never fire for AI credit subscription downgrades.

This may be intentional — the `handle_subscription_schedule_downgrade` method was built for main-plan downgrades, and AI credit downgrades might not need these notifications. Flagging as informational.

---

### LOW-2: Modal styled component pattern diverges from analogs

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx`

**Evidence:** The cancel and purchase confirm modals use `Styled.Body` (flex column with padding and gap) and `Styled.ButtonRow` (flex row justified to flex-end). The new update modal uses no body wrapper and `Styled.ButtonContainer` (flex row with margin-right pattern). This is a minor structural inconsistency — it works correctly but doesn't match the established modal pattern.

---

## Verdict: FAIL

**Blocking issues:**
- BLOCKER-1: The `checkout` action calls two nonexistent model methods and will crash with `NoMethodError`. New subscriptions cannot be created.

**High-severity issues requiring attention:**
- HIGH-1: `.reload` in application code violates `cursor_rules/backend/_base.md` rule 8.
- HIGH-2: Downgrade interactor does not update local state, deviating from the cancel analog's pattern and causing stale data in the API response.
- HIGH-3: `isCurrent` uses deprecated Stripe `plan.id` field instead of the already-extracted `currentPriceObject`.
