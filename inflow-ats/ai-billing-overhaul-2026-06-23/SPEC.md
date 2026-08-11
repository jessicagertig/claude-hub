# SPEC: Custom AI Credit Subscription Upgrade/Downgrade

## Summary

Replace the Stripe customer portal-based AI credit subscription change flow with direct Stripe API calls and a custom confirmation modal. Currently, when an existing AI credit subscriber clicks a different tier card, the app creates a `Stripe::BillingPortal::Session` and redirects the user to Stripe's hosted portal for confirmation. The new flow keeps the user in-app: show a custom modal with real Stripe amounts from `Invoice.create_preview`, and on confirmation call `Stripe::Subscription.update` to commit the change. The subscription ID stays the same throughout -- only the subscription item's price changes.

**Upgrade** = moving to a tier with more credits (e.g. Lite 500 credits -> Plus 1,000 credits). Charges the full monthly price difference immediately. Grants the difference in credits on `invoice.paid`.

**Downgrade** = moving to a tier with fewer credits (e.g. Plus 1,000 credits -> Lite 500 credits). Schedules the plan change at period end via `Stripe::SubscriptionSchedule`. No charge today. Customer keeps current credits until then.

## Stack scope

- **Backend:** Ruby/Rails controller actions, interactor, Stripe service, webhook handler modifications
- **Frontend:** React modal component, React Query mutation hooks, TypeScript types, modifications to `AiCreditSubscription.tsx`
- **No data model changes** (no new columns, no new tables, no new enum values)
- **No new migrations**

---

## Data model changes

None. The existing `OrganizationAiCreditPurchase` model, `AiCreditBalanceTransaction` model, and `OrganizationAiCreditBalance` model are sufficient. The `customer.subscription.updated` webhook handler already updates `stripe_price_lookup_key` and `subscription_credits_per_period` on the purchase row when the plan changes. The `invoice.paid` handler already grants credits for subscription invoices. The only changes are to how the upgrade invoice is handled (distinguishing `billing_reason: 'subscription_update'` from `billing_reason: 'subscription_cycle'`).

Existing columns used:
- `OrganizationAiCreditPurchase#stripe_price_lookup_key` -- updated by `customer.subscription.updated` webhook on plan change
- `OrganizationAiCreditPurchase#subscription_credits_per_period` -- updated by `customer.subscription.updated` webhook on plan change
- `OrganizationAiCreditPurchase#stripe_subscription_id` -- used to find the purchase and to call `Stripe::Subscription.update`
- `OrganizationAiCreditPurchase#subscription_current_period_start` -- used for `proration_date` param
- `OrganizationAiCreditPurchase#subscription_current_period_end` -- shown in downgrade modal as effective date

Existing enum values used:
- `AiCreditBalanceTransaction.entry_type: :subscription_credit_pack_purchase_credit` (value 30) -- used for upgrade credit grants (same entry type as renewal grants; the description string distinguishes them)
- `AiCreditBalanceTransaction.bucket: :addon_subscription` (value 2) -- used for upgrade credit grants

---

## API changes

### Backend: New controller action `preview_subscription_change`

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`

**Action:** `preview_subscription_change` (POST)

**Authorization:** `authorize :billing, :change_subscription?` (same as `change_subscription_portal_session`, requires `is_org_admin?` via `BillingPolicy`)

**What it does:**
1. Find the active subscription purchase: `current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])`
2. Guard: raise `StandardError` if no `stripe_customer_id`, no active subscription, or no `stripe_subscription_id`
3. Retrieve the live Stripe subscription: `Stripe::Subscription.retrieve(organization_ai_credit_purchase.stripe_subscription_id)`
4. Extract the subscription item ID from the live subscription: `stripe_subscription.items.data.first.id`
5. Call `Stripe::Invoice.create_preview` with the subscription, the new price, and proration params
6. Return the preview data as JSON to the frontend

**Stripe API call:**
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

Note on `proration_date`: Setting this to `subscription_current_period_start` (the start of the current billing period) causes Stripe to compute the proration as if the entire period is remaining, producing full-price math (new plan full price minus current plan full price) rather than time-prorated fractions. This achieves the approved decision #3 requirement. The exact param may need adjustment based on Stripe API behavior -- the goal (full monthly price difference) is what matters.

**Response shape:**
```json
{
  "amountDue": 9000,
  "currency": "usd",
  "lines": [
    {
      "amount": -3900,
      "description": "Unused time on ...",
      "price": { "lookupKey": "plato_ai_credit_subscription_small" }
    },
    {
      "amount": 12900,
      "description": "Remaining time on ...",
      "price": { "lookupKey": "plato_ai_credit_subscription_medium" }
    }
  ],
  "subscriptionItemId": "si_XXX",
  "currentPeriodEnd": 1753056000,
  "defaultPaymentMethod": {
    "brand": "visa",
    "last4": "4242"
  }
}
```

The controller builds this response from the preview invoice. For the line items, extract `amount`, `description`, and `price.lookup_key` from each `preview.lines.data` entry. For `defaultPaymentMethod`, retrieve the customer's default payment method from the subscription or customer object: `Stripe::PaymentMethod.retrieve(stripe_subscription.default_payment_method || Stripe::Customer.retrieve(current_organization.stripe_customer_id).invoice_settings.default_payment_method)` -- extract `card.brand` and `card.last4`. For `currentPeriodEnd`, use `stripe_subscription.current_period_end`.

**Error handling:** Rescue `Stripe::StripeError` at method level (same pattern as `cancel` action). Log with `Rails.logger.error`, `ap`, and `Sentry.capture_exception`. Render `render_general_errors` with a user-facing message.

### Backend: New controller action `commit_subscription_change`

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`

**Action:** `commit_subscription_change` (POST)

**Authorization:** `authorize :billing, :change_subscription?` (same policy method)

**What it does:**
1. Find the active subscription purchase (same query as `preview_subscription_change`)
2. Guard: same guards as preview
3. Retrieve the new price from Stripe to obtain the lookup key: `new_price = Stripe::Price.retrieve(determine_price_id)`, then `new_lookup_key = new_price.lookup_key`
4. Determine if this is an upgrade or downgrade server-side: compare `OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(organization_ai_credit_purchase.stripe_price_lookup_key)` vs `OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(new_lookup_key)`. The frontend does NOT send `isDowngrade` -- the backend computes it from the lookup keys to prevent a client from bypassing the downgrade scheduling.
5. For upgrades: call `Stripe::Subscription.update` with identical params to the preview
6. For downgrades: call the `ScheduleAiCreditSubscriptionDowngrade` interactor
7. Return the updated purchase as JSON via `Api::V1::OrganizationAiCreditPurchaseSerializer`

**Upgrade path -- Stripe API call:**
```ruby
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

The params match the preview call exactly (approved decision #2: what was shown matches what Stripe charges).

**Downgrade path:** Delegate to `ScheduleAiCreditSubscriptionDowngrade` interactor (see below).

**Response:** `render_one(organization_ai_credit_purchase.reload, Api::V1::OrganizationAiCreditPurchaseSerializer)` on success.

**Error handling:** Same pattern as `cancel` -- rescue `Stripe::StripeError`, log, Sentry, `render_general_errors`.

### Backend: New interactor `ScheduleAiCreditSubscriptionDowngrade`

**File:** `app/interactors/schedule_ai_credit_subscription_downgrade.rb`

**Pattern:** Follows `CancelAiCreditSubscription` interactor pattern -- Stripe-first, then local state. If Stripe fails, local state is untouched.

**Inputs:**
- `context.purchase` -- the `OrganizationAiCreditPurchase` (kind: subscription) to downgrade
- `context.new_price_id` -- the Stripe price ID for the target lower tier

**What it does:**
1. Create or update a `Stripe::SubscriptionSchedule` that transitions the subscription to the new price at the end of the current billing period
2. The interactor does NOT update local purchase fields -- the `subscription_schedule.updated` webhook handler already handles that (via `handle_subscription_schedule_downgrade`)

**Stripe API call:**
```ruby
# Create a schedule from the existing subscription, then update it with two phases:
# Phase 1 (current): keep current price until period end
# Phase 2 (next): switch to new price, auto-renew indefinitely
schedule = Stripe::SubscriptionSchedule.create(
  from_subscription: organization_ai_credit_purchase.stripe_subscription_id
)

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

Note: The exact SubscriptionSchedule API usage may need refinement. The `handle_subscription_schedule_downgrade` method in `StripeWebhookHandlerJob` already handles `subscription_schedule.updated` and `subscription_schedule.created` events. However, its `downgrade_detected?` method only recognizes ATS plan tiers (`free/starter/growth/scale/enterprise`), NOT AI credit subscription lookup keys (`plato_ai_credit_subscription_small/medium/large`). The handler will execute for AI credit schedule events (it finds the org by `stripe_customer_id`) but `downgrade_detected?` will return `false`, so Discord/engagement-report notifications will NOT fire for AI credit subscription downgrades. Adding AI credit tier recognition to `downgrade_detected?` is out of scope for this feature.

**Failure modes:**
- `Stripe::StripeError` -- context fails with `:stripe_error`, local state untouched
- If the subscription already has a pending schedule, the create call may need to update the existing schedule instead

### Backend: Remove or deprecate portal-based actions

The following controller actions become unused and should be removed:

1. `change_subscription_portal_session` -- replaced by `preview_subscription_change` + `commit_subscription_change`
2. `update_payment_method_and_subscription_portal_session` -- replaced by the same new actions (payment method update, if needed, can be handled separately)
3. `continue_change_subscription_portal_session` -- the redirect-continuation endpoint for the portal flow; no longer needed

The corresponding routes in `config/routes.rb` should also be removed:
```ruby
# Remove these three lines:
post :change_subscription_portal_session
post :update_payment_method_and_subscription_portal_session
get :continue_change_subscription_portal_session
```

And add the new routes:
```ruby
post :preview_subscription_change
post :commit_subscription_change
```

### Backend: Modify `handle_subscription_credit_pack_invoice_paid` to handle upgrade invoices

**File:** `app/jobs/stripe_webhook_handler_job.rb`

**Current behavior:** `handle_subscription_credit_pack_invoice_paid` is called for ALL credit-pack subscription invoices. It stamps payment info on the purchase row and calls `ApplyAiCreditPurchase.call(invoice: invoice, kind: :subscription, purchase: organization_ai_credit_purchase)`, which grants `subscription_credits_per_period` credits.

**New behavior:** Before calling `ApplyAiCreditPurchase`, check the invoice's `billing_reason`:

```ruby
def handle_subscription_credit_pack_invoice_paid(invoice)
  organization_ai_credit_purchase = OrganizationAiCreditPurchase.find_by(
    stripe_subscription_id: invoice.subscription,
    kind: :subscription
  )
  raise CustomStripeSubscriptionMissingError if organization_ai_credit_purchase.nil?

  updated = organization_ai_credit_purchase.update(
    stripe_amount: invoice.amount_paid,
    currency: invoice.currency,
    stripe_invoice_item_id: invoice.lines.data.first&.id
  )
  unless updated
    Rails.logger.error "Stripe invoice.paid: could not persist payment info on organization_ai_credit_purchase #{organization_ai_credit_purchase.id}: #{organization_ai_credit_purchase.errors.full_messages.join(', ')}"
    ap organization_ai_credit_purchase.errors
  end

  if invoice.billing_reason == 'subscription_update'
    # Upgrade proration invoice: grant the DIFFERENCE in credits, not the full period amount.
    ApplyAiCreditUpgrade.call(invoice: invoice, purchase: organization_ai_credit_purchase)
  else
    # billing_reason is 'subscription_cycle' (renewal) or 'subscription_create' (first invoice)
    ApplyAiCreditPurchase.call(invoice: invoice, kind: :subscription, purchase: organization_ai_credit_purchase)
  end
end
```

### Backend: New interactor `ApplyAiCreditUpgrade`

**File:** `app/interactors/apply_ai_credit_upgrade.rb`

**Pattern:** Follows `ApplyAiCreditPurchase` interactor pattern.

**Inputs:**
- `context.invoice` -- the Stripe invoice object (billing_reason: 'subscription_update')
- `context.purchase` -- the `OrganizationAiCreditPurchase` row

**What it does:**
1. Extract old and new plan lookup keys from the invoice line items
2. Compute the credit difference
3. Grant the difference as a credit transaction
4. Idempotency: check if a grant for this invoice already exists

**Extracting lookup keys from the invoice:**

The `subscription_update` invoice has two line items (confirmed by the real Stripe invoice example at `stripe-invoice-subscription-update-example.json`):
- A negative-amount line (credit for old plan) -- its `price.lookup_key` identifies the old plan
- A positive-amount line (charge for new plan) -- its `price.lookup_key` identifies the new plan

```ruby
def call
  invoice = context.invoice
  organization_ai_credit_purchase = context.purchase

  organization = organization_ai_credit_purchase.organization
  balance = organization.organization_ai_credit_balance
  unless balance
    Rails.logger.error "ApplyAiCreditUpgrade: org #{organization.id} has no ai_credit_balance"
    return context.fail!(error: :missing_balance, message: "org #{organization.id} has no balance")
  end

  # Idempotency: if this invoice was already processed, do not double-grant
  return if organization_ai_credit_purchase.stripe_invoice_id == invoice.id

  # Extract old and new lookup keys from invoice line items
  old_line = invoice.lines.data.find { |line| line.amount.negative? }
  new_line = invoice.lines.data.find { |line| line.amount.positive? }

  unless old_line && new_line
    Rails.logger.error "ApplyAiCreditUpgrade: invoice #{invoice.id} does not have expected old/new line items"
    return context.fail!(error: :invalid_invoice_lines, message: "invoice #{invoice.id} missing expected line items")
  end

  old_lookup_key = old_line.price.lookup_key
  new_lookup_key = new_line.price.lookup_key

  old_credits = OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(old_lookup_key)
  new_credits = OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(new_lookup_key)

  unless old_credits && new_credits
    Rails.logger.error "ApplyAiCreditUpgrade: unrecognized lookup keys old=#{old_lookup_key} new=#{new_lookup_key}"
    return context.fail!(error: :unrecognized_lookup_key, message: "unrecognized lookup keys")
  end

  credit_difference = new_credits - old_credits

  unless credit_difference.positive?
    Rails.logger.error "ApplyAiCreditUpgrade: credit difference is not positive (#{credit_difference}) for invoice #{invoice.id}"
    return context.fail!(error: :invalid_credit_difference, message: "credit difference not positive: #{credit_difference}")
  end

  ApplicationRecord.transaction do
    activated = organization_ai_credit_purchase.update(
      stripe_invoice_id: invoice.id
    )
    fail_with_record_invalid('invoice id stamp', organization_ai_credit_purchase.errors) unless activated

    organization_ai_credit_purchase.finalize_stripe_payment

    ai_credit_balance_transaction = AiCreditBalanceTransaction.new(
      organization_ai_credit_balance: balance,
      organization_ai_credit_purchase: organization_ai_credit_purchase,
      entry_type: :subscription_credit_pack_purchase_credit,
      bucket: :addon_subscription,
      amount: credit_difference,
      description: "Upgrade credit grant: #{old_lookup_key} -> #{new_lookup_key} (+#{credit_difference} credits)"
    )
    fail_with_record_invalid('upgrade credit grant', ai_credit_balance_transaction.errors) unless ai_credit_balance_transaction.save

    updated = balance.update(
      sent_low_notification_since_increase: false,
      sent_zero_notification_since_increase: false
    )
    fail_with_record_invalid('balance notification flag reset', balance.errors) unless updated
  end

  context.purchase = organization_ai_credit_purchase
end

private

def fail_with_record_invalid(label, errors)
  Rails.logger.error "ApplyAiCreditUpgrade #{label} failed: #{errors.full_messages.join(', ')}"
  ap errors
  context.fail!(error: :record_invalid, message: "#{label}: #{errors.full_messages.join(', ')}")
end
```

Note: `fail_with_record_invalid` is defined as a private method locally in this interactor, matching the pattern in `ApplyAiCreditPurchase` where it is also defined locally (not shared via a concern). The log message prefix is `ApplyAiCreditUpgrade` (not `ApplyAiCreditPurchase`).

**Key differences from `ApplyAiCreditPurchase`:**
- Does NOT update `subscription_status`, `subscription_current_period_start`, `subscription_current_period_end` -- those are already updated by the `customer.subscription.updated` webhook handler
- Grants `credit_difference` (new - old), not `subscription_credits_per_period`
- Uses same `entry_type: :subscription_credit_pack_purchase_credit` and `bucket: :addon_subscription` (same ledger category as renewal grants)
- Description string distinguishes upgrade grants from renewal grants

### Routes

**File:** `config/routes.rb`

**Current routes** (lines 190-202):
```ruby
resource :ai_credit_purchases, only: [:show], controller: 'organization_ai_credit_purchases' do
  collection do
    post :checkout
    post :purchase_top_up
    post :purchase_top_up_checkout_session
    post :change_subscription_portal_session
    post :update_payment_method_and_subscription_portal_session
    put :cancel
    get :prices
    get :customer_subscription
    get :continue_change_subscription_portal_session
  end
end
```

**New routes:**
```ruby
resource :ai_credit_purchases, only: [:show], controller: 'organization_ai_credit_purchases' do
  collection do
    post :checkout
    post :purchase_top_up
    post :purchase_top_up_checkout_session
    post :preview_subscription_change
    post :commit_subscription_change
    put :cancel
    get :prices
    get :customer_subscription
  end
end
```

Removed: `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`

Added: `preview_subscription_change`, `commit_subscription_change`

---

## Frontend changes

### New file: `UpdateAiCreditSubscriptionConfirmModal.tsx`

**Location:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx`

**Visual reference:** The handoff file at `~/Projects/genuine-article-images/UpdateSubscriptionConfirmModal.tsx` defines the visual design. ALL identifiers, imports, hooks, and data flow come from the codebase, not from the handoff file.

**Structural analog:** `CancelAiCreditSubscriptionConfirmModal.tsx` and `PurchaseAiCreditTopUpConfirmModal.tsx` -- same import pattern (`CenterModal`, `Button`, emotion styled components), same prop interface pattern, same `Styled` object pattern.

**Props interface:**
```typescript
interface UpdateAiCreditSubscriptionConfirmModalProps {
  onCancel: () => void;
  onConfirm: () => void;
  isLoading: boolean;
  isDowngrade: boolean;

  newPlanName: string;        // e.g. "Plus" (from AI_CREDIT_PACK_DISPLAY_NAMES)
  newPlanCredits: number;     // e.g. 1000 (from AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY)
  newMonthlyPrice: string;    // e.g. "$129.00" (from tier.priceDollars -- the actual monthly price, NOT the prorated invoice line amount)
  startDate: string;          // e.g. "Jul 15, 2026" (formatted via prettyDate from currentPeriodEnd)
  paymentMethodLabel: string; // e.g. "Visa 4242" (from preview response defaultPaymentMethod)

  // Upgrade only:
  amountDueToday: string;         // e.g. "$90.00" (formatted from preview amountDue)
  currentPlanName: string;        // e.g. "Lite" (from AI_CREDIT_PACK_DISPLAY_NAMES)
  creditForCurrentPlan: string;   // e.g. "-$39.00" (formatted from preview line item)

  // Downgrade only:
  currentPlanCredits: number;     // e.g. 1000 (current tier's credits)
}
```

**Visual layout (upgrade):**
- Header: "Confirm your update" (CenterModal headerTitleText)
- Plan line: "{newPlanName} -- {newPlanCredits} credits / month"
- "What you'll pay monthly starting {startDate}" row with newMonthlyPrice
- Divider
- Expandable "View details" / "Hide details" toggle showing:
  - "{newPlanName} plan" -> {newMonthlyPrice}
  - "Credit for current {currentPlanName} plan" -> {creditForCurrentPlan}
  - Divider
  - "Total" -> {amountDueToday}
- "Amount due today" row with {amountDueToday}
- Meta row: toggle link + payment method label
- Terms text with links
- Button row: "Confirm" (primary) + "Cancel" (secondary)

**Visual layout (downgrade):**
- Header: "Confirm your update" (CenterModal headerTitleText)
- Plan line: "{newPlanName} -- {newPlanCredits} credits / month"
- Scheduled note paragraph explaining the change takes effect at period end
- "What you'll pay monthly starting {startDate}" row with newMonthlyPrice and payment method
- Terms text
- Button row: "Confirm change" (primary) + "Cancel" (secondary)

**Styled component pattern:** Use the `let Styled: any; Styled = {};` pattern followed by `Styled.X = styled.div(...)` assignments, matching every existing billing modal in the codebase. Use `const t: any = props.theme;` for theme access. Use emotion `css` template literals.

**Local state:** `const [showDetails, setShowDetails] = useState(false)` for the upgrade details toggle.

### Modified file: `useOrganizationAiCreditPurchase.ts`

**Location:** `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`

**Changes:**

1. **Add `previewAiCreditSubscriptionChange` mutation function and `usePreviewAiCreditSubscriptionChange` hook:**

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

2. **Add `commitAiCreditSubscriptionChange` mutation function and `useCommitAiCreditSubscriptionChange` hook:**

```typescript
interface CommitSubscriptionChangeParams {
  priceId: string;
}

const commitAiCreditSubscriptionChange = async (params: CommitSubscriptionChangeParams) => {
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

3. **Remove the following (no longer needed):**
- `changeAiCreditSubscriptionViaStripePortal` function
- `useChangeAiCreditSubscriptionViaStripePortal` hook
- `updateAiCreditSubscriptionWithPaymentMethod` function
- `useUpdateAiCreditSubscriptionWithPaymentMethod` hook
- Their exports from the `export {}` block

4. **Add the new hooks to the export block:**
```typescript
export {
  // ... existing exports ...
  usePreviewAiCreditSubscriptionChange,
  useCommitAiCreditSubscriptionChange,
};
```

### Modified file: `AiCreditSubscription.tsx`

**Location:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`

**Changes:**

1. **Update imports:**
- Remove: `useChangeAiCreditSubscriptionViaStripePortal`, `useUpdateAiCreditSubscriptionWithPaymentMethod`
- Add: `usePreviewAiCreditSubscriptionChange`, `useCommitAiCreditSubscriptionChange`
- Add: `UpdateAiCreditSubscriptionConfirmModal` import
- Add: `AI_CREDIT_PACK_DISPLAY_NAMES`, `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` from `@shared/lib/planHelpers`
- Add: `prettyDate` from `@shared/lib/time`

2. **Replace mutation hooks:**
- Remove: `useChangeAiCreditSubscriptionViaStripePortal()` destructure
- Remove: `useUpdateAiCreditSubscriptionWithPaymentMethod()` destructure
- Add: `const { mutate: previewSubscriptionChange, isLoading: isLoadingPreview } = usePreviewAiCreditSubscriptionChange();`
- Add: `const { mutate: commitSubscriptionChange, isLoading: isCommittingChange } = useCommitAiCreditSubscriptionChange();`

3. **Replace `handleChangeSubscriptionViaStripePortal` and `handleUpdateWithPaymentMethod` with `handleSelectTier`:**

The current `handleSelectTier` calls either `handleChangeSubscriptionViaStripePortal` or `handleUpdateWithPaymentMethod` based on `stripeDefaultPaymentMethodOnFile`. The new `handleSelectTier` instead:

```typescript
const handleSelectTier = (tier: AiCreditTier) => {
  const isDowngrade = currentCredits != null && tier.credits < currentCredits;

  previewSubscriptionChange(
    { priceId: tier.priceId },
    {
      onSuccess: (previewData) => {
        const newPlanName = AI_CREDIT_PACK_DISPLAY_NAMES[tier.lookupKey] || tier.name;
        const newPlanCredits = AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY[tier.lookupKey] || tier.credits;

        // Format amounts from cents to dollars
        const formatCents = (cents: number) => {
          const dollars = Math.abs(cents) / 100;
          const formatted = `$${dollars.toFixed(2)}`;
          return cents < 0 ? `-${formatted}` : formatted;
        };

        const oldLine = previewData.lines.find((line) => line.amount < 0);
        const newLine = previewData.lines.find((line) => line.amount > 0);
        const currentPlanLookupKeyFromPreview = oldLine ? oldLine.price.lookupKey : currentPlanLookupKey;
        const currentPlanNameFromPreview = currentPlanLookupKeyFromPreview
          ? AI_CREDIT_PACK_DISPLAY_NAMES[currentPlanLookupKeyFromPreview] || ""
          : "";

        const paymentMethodLabel = previewData.defaultPaymentMethod
          ? `${previewData.defaultPaymentMethod.brand.charAt(0).toUpperCase() + previewData.defaultPaymentMethod.brand.slice(1)} ${previewData.defaultPaymentMethod.last4}`
          : "";

        openModal(
          <UpdateAiCreditSubscriptionConfirmModal
            onCancel={removeModal}
            onConfirm={() => {
              commitSubscriptionChange(
                { priceId: tier.priceId },
                {
                  onSuccess: () => {
                    removeModal();
                    addToast({
                      title: isDowngrade
                        ? "Plan change scheduled"
                        : "Plan upgraded successfully",
                      kind: "success",
                    });
                  },
                  onError: (error: any) => {
                    const errorMessage =
                      error?.data?.errors?.general?.[0] ||
                      "Unable to change subscription. Please try again.";
                    addToast({ title: errorMessage, kind: "error", delay: 30000 });
                  },
                },
              );
            }}
            isLoading={isCommittingChange}
            isDowngrade={isDowngrade}
            newPlanName={newPlanName}
            newPlanCredits={newPlanCredits}
            newMonthlyPrice={tier.priceDollars}
            startDate={previewData.currentPeriodEnd ? prettyDate(previewData.currentPeriodEnd) : ""}
            paymentMethodLabel={paymentMethodLabel}
            amountDueToday={formatCents(previewData.amountDue)}
            currentPlanName={currentPlanNameFromPreview}
            creditForCurrentPlan={oldLine ? formatCents(oldLine.amount) : ""}
            currentPlanCredits={currentCredits}
          />,
        );
      },
      onError: (error: any) => {
        const errorMessage =
          error?.data?.errors?.general?.[0] || "Unable to load subscription preview.";
        addToast({ title: errorMessage, kind: "error", delay: 30000 });
      },
    },
  );
};
```

Note: The `handleSelectTier` function no longer checks `stripeDefaultPaymentMethodOnFile` to fork between portal and payment-method-update flows. The preview endpoint returns the payment method info directly, and the confirmation is handled entirely in-app. If the customer has no payment method on file, the preview call or the commit call will fail with a Stripe error, and the error toast will inform the user.

4. **Update loading states in tier cards:**
- Replace `isLoadingChangeSubscriptionViaStripePortal || isLoadingUpdateWithPaymentMethod` with `isLoadingPreview || isCommittingChange`

5. **Remove `handleChangeSubscriptionViaStripePortal` function entirely**
6. **Remove `handleUpdateWithPaymentMethod` function entirely**
7. **Keep `redirectToStripe` function** -- it is still used by `purchaseTopUpCheckoutSession` (line 231 of the current file) for the top-up checkout flow. Only the portal-related handler functions are removed.

### Modified file: `aiSubscriptionHelpers.ts`

**Location:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts`

**Changes to `deriveTierButtonText`:**

Currently, the function returns "Upgrade" when `tierCredits > currentCredits`, and "Change plan" otherwise. The function should also return "Downgrade" when `tierCredits < currentCredits` (to match the modal's `isDowngrade` logic):

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

**Changes to `deriveTierButtonType`:**

Add "Downgrade" to the secondary branch (it already falls through to secondary, but for clarity):

```typescript
export function deriveTierButtonType(buttonText: string): "primary" | "secondary" {
  if (buttonText === "Upgrade" || buttonText === "Subscribe") {
    return "primary";
  }
  return "secondary";
}
```

This change is optional -- the current implementation already returns "secondary" for "Downgrade" via the fallthrough. But the `deriveTierButtonText` change IS required so the tier cards show "Downgrade" instead of "Change plan" for lower tiers.

---

## Authorization

No new policy methods needed. Both new controller actions use `authorize :billing, :change_subscription?`, which already exists in `BillingPolicy` and requires `is_org_admin?`.

---

## Constraints

### C1: Credits granted on `invoice.paid` only, never on `customer.subscription.updated`

The `customer.subscription.updated` webhook handler (lines 111-165 of `stripe_webhook_handler_job.rb`) updates `stripe_price_lookup_key` and `subscription_credits_per_period` on the purchase row. This is correct -- it records the plan change. But credit granting MUST happen only on `invoice.paid`, after payment is confirmed. Credits are irreversible product, not permissions. The existing `customer.subscription.updated` handler does NOT grant credits, so no changes are needed there. The new `ApplyAiCreditUpgrade` interactor is called from the `invoice.paid` path only.

### C2: Invoice `billing_reason` distinguishes invoice types

The `invoice.paid` handler must check `invoice.billing_reason` to route to the correct credit granting logic:
- `'subscription_update'` -> `ApplyAiCreditUpgrade` (grant credit difference)
- `'subscription_cycle'` -> `ApplyAiCreditPurchase` (grant full `subscription_credits_per_period`)
- `'subscription_create'` -> `ApplyAiCreditPurchase` (grant full amount, first invoice)

### C3: Preview and commit params must match exactly

Approved decision #2: the commit call (`Stripe::Subscription.update`) uses identical params to the preview call (`Stripe::Invoice.create_preview`). This guarantees what was shown in the modal matches what Stripe charges. Both calls use the same `items`, `proration_behavior`, and `proration_date` params.

### C4: Subscription ID stays the same

Approved decision #1: the subscription ID does not change on upgrade or downgrade. Only the subscription item's price changes. `Stripe::Subscription.update` modifies the existing subscription in place.

### C5: Handoff file is visual reference only

Every identifier, hook name, query name, mutation name, prop name, and data flow must come from the actual codebase. The handoff file at `~/Projects/genuine-article-images/UpdateSubscriptionConfirmModal.tsx` defines the visual design (layout, sections, text copy) but not the implementation. Specifically:
- Import paths come from the codebase (`@ats/src/components/modals/CenterModal`, `@ats/src/components/shared/Button`, etc.)
- Styled component pattern matches the codebase pattern (`let Styled: any; Styled = {};`)
- Data flows through React Query mutations, not through props from a parent
- Plan names and credits come from `AI_CREDIT_PACK_DISPLAY_NAMES` and `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` in `planHelpers.ts`
- Date formatting uses `prettyDate` from `@shared/lib/time`

### C6: No `hasUnsavedChanges` on the modal

The CenterModal prop `hasUnsavedChanges` should be omitted (defaults to `false`). The cancel modal and purchase modal omit it too -- this is a confirmation modal, not a form with unsaved state.

### C7: Variable naming

All backend variable names must follow the variable naming rules. Specifically:
- `organization_ai_credit_purchase` (never `purchase` standalone)
- `ai_credit_balance_transaction` (never `transaction`)
- `organization_ai_credit_balance` (never `balance` standalone when stored in a variable referencing a record; `balance` as a local shorthand within a method where the model is unambiguous is the existing pattern in `ApplyAiCreditPurchase` and `grant_credits`)

### C8: No begin blocks in controllers

All controller actions use method-level rescue, never `begin...rescue...end` blocks.

### C9: Single quotes in Ruby

Use single quotes for all string literals unless interpolation is needed.

### C10: `determine_price_id` reuse

Both new controller actions use the existing private `determine_price_id` method, which reads `params[:price_id]`. The frontend posts `priceId` (camelCase), which the API layer transforms to `price_id` (snake_case).

---

## Existing patterns to follow

### Cancel flow analog (`CancelAiCreditSubscription` + `Stripe::CancelCreditPackSubscription`)

The cancel flow is the closest structural analog:
- Controller action (`cancel`) finds the active subscription purchase, calls an interactor, renders the result or error
- Interactor (`CancelAiCreditSubscription`) calls Stripe first, then updates local state; if Stripe fails, local state is untouched
- Service (`Stripe::CancelCreditPackSubscription`) is a thin wrapper around the Stripe API call

The upgrade path follows this same shape:
- Controller action (`commit_subscription_change`) finds the purchase, determines upgrade vs. downgrade, calls the appropriate Stripe API (directly for upgrade, via interactor for downgrade), renders the result
- For downgrades: interactor (`ScheduleAiCreditSubscriptionDowngrade`) handles the SubscriptionSchedule creation

Note: For the upgrade `Stripe::Subscription.update` call, the controller can make this call directly (same as how `change_subscription_portal_session` makes the `Stripe::BillingPortal::Session.create` call directly). An interactor is warranted for the downgrade because the SubscriptionSchedule API is multi-step. The upgrade is a single Stripe API call with no local state changes needed (the `customer.subscription.updated` and `invoice.paid` webhooks handle all local state).

### Credit granting analog (`ApplyAiCreditPurchase`)

`ApplyAiCreditUpgrade` follows the same transaction pattern:
- Wrap in `ApplicationRecord.transaction`
- Update the purchase's `stripe_invoice_id` for idempotency
- Call `finalize_stripe_payment` on the purchase
- Create an `AiCreditBalanceTransaction` with `save` (not `save!`)
- Check the save return value and call `fail_with_record_invalid` on failure
- Reset balance notification flags

### Modal component analog (`CancelAiCreditSubscriptionConfirmModal.tsx`, `PurchaseAiCreditTopUpConfirmModal.tsx`)

Both modals follow the same pattern:
- Functional component with Props interface
- `CenterModal` wrapper with `headerTitleText` and `onCancel`
- `Button` components for actions
- `Styled` object pattern for emotion styles
- `const t: any = props.theme;` for theme access

### Mutation hook analog (`useChangeAiCreditSubscriptionViaStripePortal`)

The new `usePreviewAiCreditSubscriptionChange` and `useCommitAiCreditSubscriptionChange` follow the same pattern:
- Async function calling `apiPost` with `path` and `variables`
- `useMutation` wrapper
- `onSuccess` callback invalidating relevant query keys
- Export from the hook file

### Webhook handler routing analog (existing `invoice.paid` handler)

The existing `invoice.paid` handler already routes by metadata and lookup key. The new routing adds a `billing_reason` check within the credit-pack branch. This is a read of a Stripe-set field (not a new column or metadata key).

---

## Files modified (complete list)

### Backend (under `app/`)
| File | Action |
|------|--------|
| `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` | Add `preview_subscription_change`, `commit_subscription_change`; remove `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session` |
| `app/interactors/apply_ai_credit_upgrade.rb` | **New file** -- upgrade credit granting interactor |
| `app/interactors/schedule_ai_credit_subscription_downgrade.rb` | **New file** -- downgrade scheduling interactor |
| `app/jobs/stripe_webhook_handler_job.rb` | Modify `handle_subscription_credit_pack_invoice_paid` to check `billing_reason` and route to `ApplyAiCreditUpgrade` for `subscription_update` invoices |
| `config/routes.rb` | Remove 3 portal routes, add 2 new routes |

### Frontend (under `app/javascript/`)
| File | Action |
|------|--------|
| `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx` | **New file** -- confirmation modal component |
| `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` | Add `usePreviewAiCreditSubscriptionChange`, `useCommitAiCreditSubscriptionChange`; remove `useChangeAiCreditSubscriptionViaStripePortal`, `useUpdateAiCreditSubscriptionWithPaymentMethod` |
| `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` | Replace portal flow with preview+modal+commit flow in `handleSelectTier`; update imports and loading states |
| `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts` | Update `deriveTierButtonText` to return "Downgrade" for lower tiers |

### Not modified
| File | Reason |
|------|--------|
| `app/models/organization_ai_credit_purchase.rb` | No new columns, methods, or enums needed |
| `app/models/ai_credit_balance_transaction.rb` | No new entry_type or bucket values needed |
| `app/models/organization_ai_credit_balance.rb` | No changes |
| `app/interactors/apply_ai_credit_purchase.rb` | Not modified -- continues to handle renewal and first-invoice grants |
| `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb` | No new attributes needed |
| `app/policies/billing_policy.rb` | `change_subscription?` already exists |
| `app/javascript/shared/types/organizationAiCreditPurchase.ts` | No new fields |
| `app/javascript/shared/lib/planHelpers.ts` | No changes needed (already has `AI_CREDIT_PACK_DISPLAY_NAMES` and `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY`) |

---

## Test requirements

### Backend specs needed

1. **Controller spec: `preview_subscription_change`**
   - Success case: returns preview data with correct shape
   - No active subscription: renders error
   - Non-admin user: returns 403 (Pundit)
   - Stripe error: renders error message

2. **Controller spec: `commit_subscription_change`**
   - Upgrade success: calls `Stripe::Subscription.update`, returns updated purchase
   - Downgrade success: calls `ScheduleAiCreditSubscriptionDowngrade`, returns updated purchase
   - No active subscription: renders error
   - Non-admin user: returns 403
   - Stripe error: renders error message

3. **Interactor spec: `ApplyAiCreditUpgrade`**
   - Grants correct credit difference (e.g., 1000 - 500 = 500)
   - Idempotent: does not double-grant for same invoice
   - Fails gracefully on missing balance
   - Fails on unrecognized lookup keys
   - Fails on non-positive credit difference
   - Creates correct `AiCreditBalanceTransaction` (entry_type, bucket, amount, description)
   - Resets notification flags on balance

4. **Interactor spec: `ScheduleAiCreditSubscriptionDowngrade`**
   - Creates SubscriptionSchedule with correct phases
   - Fails with `:stripe_error` on Stripe failure (local state untouched)

5. **Webhook handler spec: `handle_subscription_credit_pack_invoice_paid` with `billing_reason: 'subscription_update'`**
   - Routes to `ApplyAiCreditUpgrade` instead of `ApplyAiCreditPurchase`
   - Renewal invoices (`billing_reason: 'subscription_cycle'`) still route to `ApplyAiCreditPurchase`

### Existing specs to update

- Controller specs for `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session` should be removed (actions removed)

---

## Sequence diagram

### Upgrade flow

```
User clicks "Upgrade" on tier card
  -> AiCreditSubscription.handleSelectTier(tier)
  -> POST /ai_credit_purchases/preview_subscription_change { priceId }
    -> Controller calls Stripe::Invoice.create_preview
    -> Controller returns preview JSON
  -> Frontend opens UpdateAiCreditSubscriptionConfirmModal with preview data
  -> User clicks "Confirm"
  -> POST /ai_credit_purchases/commit_subscription_change { priceId }
    -> Controller determines upgrade (server-side lookup key comparison)
    -> Controller calls Stripe::Subscription.update (same params as preview)
    -> Stripe processes immediately:
      1. customer.subscription.updated webhook fires
         -> StripeWebhookHandlerJob updates purchase row (lookup_key, credits_per_period, status, period dates)
      2. invoice.paid webhook fires (billing_reason: 'subscription_update')
         -> handle_subscription_credit_pack_invoice_paid routes to ApplyAiCreditUpgrade
         -> ApplyAiCreditUpgrade extracts old/new lookup keys from invoice lines
         -> Computes credit difference, creates AiCreditBalanceTransaction
    -> Controller returns updated purchase
  -> Frontend shows success toast, invalidates queries
```

### Downgrade flow

```
User clicks "Downgrade" on tier card
  -> AiCreditSubscription.handleSelectTier(tier)
  -> POST /ai_credit_purchases/preview_subscription_change { priceId }
    -> Controller calls Stripe::Invoice.create_preview
    -> Controller returns preview JSON (amountDue will be 0 or negative)
  -> Frontend opens UpdateAiCreditSubscriptionConfirmModal with isDowngrade=true
  -> User clicks "Confirm change"
  -> POST /ai_credit_purchases/commit_subscription_change { priceId }
    -> Controller determines downgrade (server-side lookup key comparison)
    -> Controller calls ScheduleAiCreditSubscriptionDowngrade interactor
    -> Interactor creates Stripe::SubscriptionSchedule
    -> Stripe fires subscription_schedule.updated webhook
      -> handle_subscription_schedule_downgrade runs but downgrade_detected? returns false
         (AI credit lookup keys not in ATS tier hierarchy -- no Discord/engagement notifications)
    -> At period end, Stripe automatically transitions the subscription
    -> customer.subscription.updated fires with new price
    -> invoice.paid fires for the new period (billing_reason: 'subscription_cycle')
      -> Normal renewal credit grant at the new (lower) amount
  -> Frontend shows "Plan change scheduled" toast, invalidates queries
```
