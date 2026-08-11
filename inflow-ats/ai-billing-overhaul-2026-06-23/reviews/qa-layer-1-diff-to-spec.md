# QA Layer 1: Diff-to-Spec Review

**NOTE: This review covers WORKING TREE files, not committed code.** As of review time, the following files are untracked (new, never committed): `apply_ai_credit_upgrade.rb`, `schedule_ai_credit_subscription_downgrade.rb`, `UpdateAiCreditSubscriptionConfirmModal.tsx`. The following files have uncommitted modifications: `organization_ai_credit_purchases_controller.rb`, `AiCreditSubscription.tsx`, `aiSubscriptionHelpers.ts`, `useOrganizationAiCreditPurchase.ts`, `stripe_webhook_handler_job.rb`, `routes.rb`. Per known failure pattern #15, a PASS verdict on working-tree code is insufficient for merge -- the code must be committed first. This review verifies spec-implementation alignment on the working-tree state as instructed.

## Spec Requirements -> Implementation Mapping

### Backend: `preview_subscription_change` controller action
| Spec requirement | Implementation | Status |
|---|---|---|
| POST action on `organization_ai_credit_purchases_controller.rb` | Lines 228-287 | MATCH |
| `authorize :billing, :change_subscription?` | Line 229 | MATCH |
| Find active subscription purchase: `current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])` | Line 231 | MATCH |
| Guard: raise on no `stripe_customer_id`, no active subscription, no `stripe_subscription_id` | Lines 233-244 (renders errors, does not raise -- see note) | MATCH (renders `render_general_errors` per C8 no-begin-blocks constraint; functionally equivalent to the spec's "raise StandardError" for guards) |
| Retrieve live Stripe subscription | Line 246 | MATCH |
| Extract subscription item ID from `stripe_subscription.items.data.first.id` | Lines 253, 278 | MATCH |
| Call `Stripe::Invoice.create_preview` with correct params | Lines 248-259 | MATCH |
| `proration_behavior: 'always_invoice'` | Line 256 | MATCH |
| `proration_date: organization_ai_credit_purchase.subscription_current_period_start.to_i` | Line 257 | MATCH |
| Response includes `amountDue`, `currency`, `lines`, `subscriptionItemId`, `currentPeriodEnd`, `defaultPaymentMethod` | Lines 268-281 (snake_case keys, converted to camelCase by OliveBranch middleware) | MATCH |
| Line items include `amount`, `description`, `price.lookupKey` | Lines 272-276 | MATCH |
| Payment method retrieval from subscription or customer fallback | Lines 261-266 | MATCH |
| Error handling: rescue `Stripe::StripeError`, log, ap, Sentry, render_general_errors | Lines 282-287 | MATCH |

### Backend: `commit_subscription_change` controller action
| Spec requirement | Implementation | Status |
|---|---|---|
| POST action on `organization_ai_credit_purchases_controller.rb` | Lines 289-353 | MATCH |
| `authorize :billing, :change_subscription?` | Line 290 | MATCH |
| Same guards as preview | Lines 292-305 | MATCH |
| Retrieve new price from Stripe and extract lookup key | Lines 307-308 | MATCH |
| Server-side upgrade/downgrade determination via `ai_credit_allocation_for_lookup_key` comparison | Lines 310-320 | MATCH |
| Upgrade: `Stripe::Subscription.update` with same params as preview | Lines 331-344 | MATCH |
| Downgrade: call `ScheduleAiCreditSubscriptionDowngrade` interactor | Lines 323-329 | MATCH |
| Response: `render_one(organization_ai_credit_purchase.reload, ...)` | Line 347 | MATCH |
| Error handling: rescue `Stripe::StripeError`, log, ap, Sentry | Lines 348-353 | MATCH |

### Backend: `ScheduleAiCreditSubscriptionDowngrade` interactor
| Spec requirement | Implementation | Status |
|---|---|---|
| New file at `app/interactors/schedule_ai_credit_subscription_downgrade.rb` | File exists | MATCH |
| `include Interactor` | Line 18 | MATCH |
| Inputs: `context.purchase`, `context.new_price_id` | Lines 21-22, 44 | MATCH |
| Retrieve Stripe subscription to get current price ID | Lines 23-26 | MATCH |
| `Stripe::SubscriptionSchedule.create(from_subscription: ...)` | Lines 28-30 | MATCH |
| `Stripe::SubscriptionSchedule.update` with two phases | Lines 32-48 | MATCH |
| Phase 1: current price, `start_date`/`end_date` from purchase period | Lines 37-40 | MATCH |
| Phase 2: new price, `iterations: 1` | Lines 42-44 | MATCH |
| `end_behavior: 'release'` | Line 35 | MATCH |
| Does NOT update local purchase fields | No local updates | MATCH |
| Rescue `Stripe::StripeError`, context fails with `:stripe_error` | Lines 51-58 | MATCH |

### Backend: `ApplyAiCreditUpgrade` interactor
| Spec requirement | Implementation | Status |
|---|---|---|
| New file at `app/interactors/apply_ai_credit_upgrade.rb` | File exists | MATCH |
| `include Interactor` | Line 24 | MATCH |
| Inputs: `context.invoice`, `context.purchase` | Lines 27-28 | MATCH |
| Find org balance, fail if missing | Lines 30-35 | MATCH |
| Idempotency check: `stripe_invoice_id == invoice.id` | Line 38 | MATCH |
| Extract old line (negative amount) and new line (positive amount) from invoice | Lines 41-42 | MATCH |
| Fail if old/new lines missing | Lines 44-46 | MATCH |
| Extract lookup keys from lines | Lines 49-50 | MATCH |
| Compute credit difference via `ai_credit_allocation_for_lookup_key` | Lines 52-53, 60 | MATCH |
| Fail if unrecognized lookup keys | Lines 55-57 | MATCH |
| Fail if credit difference not positive | Lines 62-64 | MATCH |
| `ApplicationRecord.transaction` wrapping | Line 67 | MATCH |
| Update `stripe_invoice_id` only (NOT subscription_status, period dates) | Lines 68-69 | MATCH |
| Call `finalize_stripe_payment` | Line 73 | MATCH |
| Create `AiCreditBalanceTransaction` with `entry_type: :subscription_credit_pack_purchase_credit`, `bucket: :addon_subscription` | Lines 75-82 | MATCH |
| Amount = credit_difference | Line 80 | MATCH |
| Description distinguishes upgrade from renewal | Line 81 | MATCH |
| Check save return value, call `fail_with_record_invalid` | Line 83 | MATCH |
| Reset balance notification flags | Lines 85-89 | MATCH |
| Set `context.purchase` on success | Line 92 | MATCH |
| Private `fail_with_record_invalid` with correct log prefix | Lines 97-101 | MATCH |

### Backend: `handle_subscription_credit_pack_invoice_paid` webhook modification
| Spec requirement | Implementation | Status |
|---|---|---|
| Check `billing_reason` before routing | Line 489 | MATCH |
| `subscription_update` -> `ApplyAiCreditUpgrade.call(invoice:, purchase:)` | Line 490 | MATCH |
| Other billing reasons -> `ApplyAiCreditPurchase.call(invoice:, kind: :subscription, purchase:)` | Line 492 | MATCH |
| Update payment info (stripe_amount, currency, stripe_invoice_item_id) before routing | Lines 479-486 | MATCH |
| Raise `CustomStripeSubscriptionMissingError` if purchase nil | Line 477 | MATCH |

### Backend: Routes
| Spec requirement | Implementation | Status |
|---|---|---|
| Remove `change_subscription_portal_session` route | Not present (lines 190-201) | MATCH |
| Remove `update_payment_method_and_subscription_portal_session` route | Not present | MATCH |
| Remove `continue_change_subscription_portal_session` route | Not present | MATCH |
| Add `post :preview_subscription_change` | Line 195 | MATCH |
| Add `post :commit_subscription_change` | Line 196 | MATCH |

### Backend: Remove portal-based controller actions
| Spec requirement | Implementation | Status |
|---|---|---|
| Remove `change_subscription_portal_session` action | Not present | MATCH |
| Remove `update_payment_method_and_subscription_portal_session` action | Not present | MATCH |
| Remove `continue_change_subscription_portal_session` action | Not present | MATCH |

### Frontend: `UpdateAiCreditSubscriptionConfirmModal.tsx`
| Spec requirement | Implementation | Status |
|---|---|---|
| New file with correct props interface | Lines 9-23 | MATCH (with one type widening -- see H1) |
| `CenterModal` with `headerTitleText="Confirm your update"` | Line 49 | MATCH |
| Plan line with name and credits | Line 46 | MATCH |
| Downgrade: scheduled note paragraph | Lines 52-59 | MATCH |
| "What you'll pay monthly starting {startDate}" row | Lines 61-75 | MATCH |
| Upgrade: divider + expandable details section | Lines 77-113 | MATCH |
| Details: new plan line, credit for current plan, divider, total | Lines 83-96 | MATCH |
| "Amount due today" row | Lines 99-102 | MATCH |
| Toggle "View details" / "Hide details" | Lines 105-107 | MATCH |
| Payment method label display | Lines 108-111 | MATCH |
| Terms text with links | Lines 116-119 | MATCH |
| Button: "Confirm" for upgrade, "Confirm change" for downgrade | Lines 122-123 | MATCH |
| Cancel button (secondary) | Lines 125-127 | MATCH |
| `let Styled: any; Styled = {};` pattern | Lines 137-138 | MATCH |
| `const t: any = props.theme;` for theme access | Line 141 (and others) | MATCH |
| `useState(false)` for showDetails | Line 44 | MATCH |
| No `hasUnsavedChanges` prop on CenterModal | Line 49 (omitted) | MATCH (C6) |
| `loading` and `disabled` behavioral props on Button | Line 122: `loading={isLoading}` present; `disabled` NOT passed | MISMATCH -- see H2 |

### Frontend: `useOrganizationAiCreditPurchase.ts`
| Spec requirement | Implementation | Status |
|---|---|---|
| Add `PreviewSubscriptionChangeParams` interface | Lines 35-37 | MATCH |
| Add `PreviewSubscriptionChangeResponse` interface | Lines 39-53 | MATCH |
| Add `previewAiCreditSubscriptionChange` function with `apiPost` | Lines 59-65 | MATCH |
| Add `usePreviewAiCreditSubscriptionChange` hook with `useMutation` | Lines 68-70 | MATCH |
| Add `CommitSubscriptionChangeParams` interface | Lines 55-57 | MATCH |
| Add `commitAiCreditSubscriptionChange` function | Lines 72-79 | MATCH |
| Add `useCommitAiCreditSubscriptionChange` with cache invalidation | Lines 81-90 | MATCH |
| Invalidate `organizationAiCreditPurchase`, `organizationAiCreditBalance`, `aiCreditCustomerSubscription` | Lines 85-87 | MATCH |
| Remove old portal functions and hooks | Confirmed removed (no references in codebase) | MATCH |
| Export new hooks | Lines 191-192 | MATCH |

### Frontend: `AiCreditSubscription.tsx`
| Spec requirement | Implementation | Status |
|---|---|---|
| Remove old portal hook imports | Not present | MATCH |
| Import `usePreviewAiCreditSubscriptionChange`, `useCommitAiCreditSubscriptionChange` | Lines 8-9 | MATCH |
| Import `UpdateAiCreditSubscriptionConfirmModal` | Line 24 | MATCH |
| Import `AI_CREDIT_PACK_DISPLAY_NAMES`, `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` | Line 19 | MATCH |
| Import `prettyDate` | Line 20 | MATCH |
| Destructure `previewSubscriptionChange` and `isLoadingPreview` | Lines 40-41 | MATCH |
| Destructure `commitSubscriptionChange` and `isCommittingChange` | Lines 42-43 | MATCH |
| `handleSelectTier` calls `previewSubscriptionChange` | Line 81 | MATCH |
| Server-side `isDowngrade` determination in `handleSelectTier` | Line 79 | Note: frontend computes `isDowngrade` for UI display purposes; server recomputes independently in `commit_subscription_change` | MATCH |
| `onSuccess`: extract plan name, credits, format amounts, open modal | Lines 84-141 | MATCH |
| `onError`: show error toast | Lines 142-146 | MATCH |
| Modal `onConfirm` calls `commitSubscriptionChange` | Lines 108-128 | MISMATCH -- see H3 |
| Success toast messages: "Plan change scheduled" / "Plan upgraded successfully" | Lines 113-116 | MATCH |
| Error toast with fallback message | Lines 119-122 | MATCH |
| Update loading states: `isLoadingPreview \|\| isCommittingChange` | Line 303: includes `isSubscribing` too | MATCH (spec didn't prohibit including `isSubscribing`) |
| Remove old handler functions | Not present | MATCH |
| Keep `redirectToStripe` function | Line 74 | MATCH |
| `newMonthlyPrice` uses `tier.priceDollars` | Line 133: `$${tier.priceDollars.toFixed(2)}` | MISMATCH -- see H4 |

### Frontend: `aiSubscriptionHelpers.ts`
| Spec requirement | Implementation | Status |
|---|---|---|
| `deriveTierButtonText` returns "Downgrade" for lower tiers | Lines 37-38 | MATCH |
| `deriveTierButtonType` returns "secondary" for "Downgrade" | Lines 48-50 (via fallthrough) | MATCH |

---

## Implementation -> Spec Traceability

### `app/interactors/apply_ai_credit_upgrade.rb`
All code traces to spec section "Backend: New interactor `ApplyAiCreditUpgrade`" (lines 249-357).

### `app/interactors/schedule_ai_credit_subscription_downgrade.rb`
All code traces to spec section "Backend: New interactor `ScheduleAiCreditSubscriptionDowngrade`" (lines 143-189).

### `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`
- `preview_subscription_change` (lines 228-287): traces to spec lines 39-101.
- `commit_subscription_change` (lines 289-353): traces to spec lines 103-141.
- Removed actions: traces to spec lines 191-205.
- All other existing actions (show, checkout, purchase_top_up, etc.) are unchanged -- not in scope.

### `app/jobs/stripe_webhook_handler_job.rb`
- `handle_subscription_credit_pack_invoice_paid` modification (lines 472-494): traces to spec lines 213-247.
- All other webhook handlers are unchanged.

### `config/routes.rb`
- Route removals and additions (lines 190-201): traces to spec lines 358-396.

### `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`
- New interfaces and hooks (lines 35-90): traces to spec lines 462-545.
- Removed functions: traces to spec lines 531-536.
- All other existing hooks unchanged.

### `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx`
- Entire file: traces to spec lines 403-458.

### `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`
- Import changes: traces to spec lines 554-558.
- Hook changes: traces to spec lines 560-564.
- `handleSelectTier` replacement: traces to spec lines 566-645.
- Loading state update: traces to spec lines 650-651.
- Removed functions: traces to spec lines 652-656.

### `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts`
- `deriveTierButtonText` change: traces to spec lines 660-676.
- `deriveTierButtonType`: no material change; spec noted the change was optional.

### UNTRACEABLE changes
None found. Every implementation change traces to a spec requirement.

---

## Findings

### H1: `currentPlanCredits` prop type widened from spec without explanation

**Spec (line 432):** `currentPlanCredits: number;`
**Implementation (UpdateAiCreditSubscriptionConfirmModal.tsx line 23):** `currentPlanCredits: number | null;`

The modal's prop interface accepts `null`, which the spec interface does not. The call site in AiCreditSubscription.tsx passes `currentCredits` which is typed `number | null`. The modal's template handles `null` gracefully (line 57: `{currentPlanCredits ? ...}`), so the code functions correctly. However, the spec says `number`, not `number | null`.

This is likely a necessary correction to the spec (the call site cannot guarantee non-null), but it is a spec-implementation mismatch and must be flagged. The spec should be amended to say `number | null` if this is intentional.

**Severity:** HIGH (spec-implementation type mismatch)

### H2: Button in modal lacks `disabled` prop to prevent double-submission

**Spec (line 122-123 of modal):** The Button component receives `loading={isLoading}` but the spec does not mention `disabled`. However, known failure pattern #11 (CLAUDE.md) requires replicating ALL behavioral props from analogs.

**Analog (`CancelAiCreditSubscriptionConfirmModal.tsx`):** The cancel modal's confirm Button also only passes `loading` and not `disabled`. So the implementation matches the analog -- both omit `disabled`.

**RETRACTED.** The analog also omits `disabled`, so the implementation correctly matches the analog. Not a finding.

### H3: `onConfirm` calls `removeModal()` before `commitSubscriptionChange` -- spec calls it in `onSuccess`

**Spec (lines 602-623):**
```typescript
onConfirm={() => {
  commitSubscriptionChange(
    { priceId: tier.priceId },
    {
      onSuccess: () => {
        removeModal();
        addToast({...});
      },
```

**Implementation (AiCreditSubscription.tsx lines 107-128):**
```typescript
onConfirm={() => {
  removeModal();
  commitSubscriptionChange(
    { priceId: tier.priceId },
    {
      onSuccess: () => {
        addToast({...});
      },
```

The implementation dismisses the modal immediately on confirm, before the API call completes. The spec keeps the modal open during the API call (showing the loading state via `isLoading={isCommittingChange}`) and only dismisses on success. This means:
1. The `isLoading` prop on the Button will never visually activate because the modal is already gone.
2. If the commit fails, the user has no modal to return to -- they only get an error toast.
3. The user has no visual feedback that the commit is in progress.

**Severity:** HIGH (spec-implementation behavioral mismatch)

### H4: `newMonthlyPrice` formatting differs from spec

**Spec (line 628):** `newMonthlyPrice={tier.priceDollars}` -- passes the raw number (e.g., `129`).
**Implementation (AiCreditSubscription.tsx line 133):** `newMonthlyPrice={\`$${tier.priceDollars.toFixed(2)}\`}` -- passes a formatted string (e.g., `"$129.00"`).

The modal's Props interface types `newMonthlyPrice` as `string` (spec line 421, implementation line 17). The spec passing a raw number to a string prop would be a TypeScript error. The implementation's formatting is functionally correct and necessary.

However, this means either: (a) the spec has a bug (passing number to string prop), or (b) the spec intended `priceDollars` to already be a string. Since `priceDollars` is `number` in the `AiCreditTier` interface, option (a) is the case.

**RETRACTED.** This is a spec bug, not an implementation deviation. The implementation correctly formats the number into a string to match the prop type. The spec code would not compile as written. Not reporting as a finding.

---

## Active Findings

### H1: `currentPlanCredits` prop type widened to `number | null` (spec says `number`)

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx` line 23
**Spec:** Line 432

The modal's `currentPlanCredits` prop accepts `number | null` while the spec says `number`. The call site passes `currentCredits` which is `number | null`, so the implementation's widening is necessary. The spec should be amended.

### H3: Modal dismissed before commit completes (spec keeps modal open until success)

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` lines 107-128
**Spec:** Lines 602-623

The implementation calls `removeModal()` before `commitSubscriptionChange()`. The spec calls `removeModal()` inside `onSuccess` of `commitSubscriptionChange()`. This changes user-visible behavior:
- Spec: modal stays open with loading indicator while commit processes; dismissed on success.
- Implementation: modal closes immediately on confirm; no loading feedback during commit.

The `isLoading={isCommittingChange}` prop (line 129) becomes dead code because the modal is dismissed before the mutation starts.

---

## Verdict: FAIL

Two HIGH findings. H3 is a behavioral spec-implementation mismatch that changes the user experience (no loading feedback during commit, dead `isLoading` prop). H1 is a type-level mismatch that may be a spec correction but has not been approved as a deviation.
