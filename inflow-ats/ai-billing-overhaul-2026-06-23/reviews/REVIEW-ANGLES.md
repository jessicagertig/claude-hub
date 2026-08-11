# Review Angles: Custom AI Credit Subscription Upgrade/Downgrade

## Subsystems touched

### Backend -- modified
| File | Action |
|------|--------|
| `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` | Add `preview_subscription_change`, `commit_subscription_change`; remove `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session` |
| `app/jobs/stripe_webhook_handler_job.rb` | Modify `handle_subscription_credit_pack_invoice_paid` to branch on `billing_reason` and route `subscription_update` to `ApplyAiCreditUpgrade` |
| `config/routes.rb` | Remove 3 portal routes, add 2 new routes |

### Backend -- new files
| File | Purpose |
|------|---------|
| `app/interactors/apply_ai_credit_upgrade.rb` | Upgrade credit granting interactor (grant credit difference on `invoice.paid`) |
| `app/interactors/schedule_ai_credit_subscription_downgrade.rb` | Downgrade scheduling interactor (create `Stripe::SubscriptionSchedule`) |

### Frontend -- modified
| File | Action |
|------|--------|
| `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` | Add `usePreviewAiCreditSubscriptionChange`, `useCommitAiCreditSubscriptionChange`; remove `useChangeAiCreditSubscriptionViaStripePortal`, `useUpdateAiCreditSubscriptionWithPaymentMethod` |
| `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` | Replace portal flow with preview+modal+commit flow in `handleSelectTier`; update imports and loading states |
| `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts` | Update `deriveTierButtonText` to return "Downgrade" for lower tiers |

### Frontend -- new files
| File | Purpose |
|------|---------|
| `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx` | Confirmation modal for upgrade and downgrade |

### Not modified (spec explicitly says no changes needed)
| File | Reason |
|------|--------|
| `app/models/organization_ai_credit_purchase.rb` | No new columns, methods, or enums |
| `app/models/ai_credit_balance_transaction.rb` | No new `entry_type` or `bucket` values |
| `app/models/organization_ai_credit_balance.rb` | No changes |
| `app/interactors/apply_ai_credit_purchase.rb` | Continues to handle renewal and first-invoice grants unchanged |
| `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb` | No new attributes |
| `app/policies/billing_policy.rb` | `change_subscription?` already exists |
| `app/javascript/shared/types/organizationAiCreditPurchase.ts` | No new fields |
| `app/javascript/shared/lib/planHelpers.ts` | Already has `AI_CREDIT_PACK_DISPLAY_NAMES` and `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` |

---

## Full-stack analog

The primary analog is the existing portal-based subscription change flow being REPLACED, plus the cancel flow (closest structural analog for the new code shape).

### Portal flow being replaced (traces what the old code did -- review must confirm complete removal)

| Layer | File | Methods/Hooks |
|-------|------|---------------|
| Controller | `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` | `change_subscription_portal_session` (lines 233-281), `update_payment_method_and_subscription_portal_session` (lines 286-338), `continue_change_subscription_portal_session` (lines 345-415) |
| Routes | `config/routes.rb` (lines 193-199) | `post :change_subscription_portal_session`, `post :update_payment_method_and_subscription_portal_session`, `get :continue_change_subscription_portal_session` |
| Frontend hooks | `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` | `changeAiCreditSubscriptionViaStripePortal` (lines 35-48), `updateAiCreditSubscriptionWithPaymentMethod` (lines 64-77), `useChangeAiCreditSubscriptionViaStripePortal`, `useUpdateAiCreditSubscriptionWithPaymentMethod` |
| Frontend component | `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` | `handleChangeSubscriptionViaStripePortal`, `handleUpdateWithPaymentMethod`, `handleSelectTier` (lines 158-170), `redirectToStripe` (line 75) |

### Cancel flow (structural analog for the new controller+interactor shape)

| Layer | File | Methods/Hooks |
|-------|------|---------------|
| Controller | `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` | `cancel` action -- same auth, same purchase lookup, same Stripe error handling pattern |
| Interactor | `app/interactors/cancel_ai_credit_subscription.rb` | Stripe-first then local state; `context.fail!` on `Stripe::StripeError`; method-level rescue |
| Service | `app/services/stripe/cancel_credit_pack_subscription.rb` | Thin wrapper: `Stripe::Subscription.update(id, cancel_at_period_end: true)` |
| Frontend hook | `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` | `useCancelAiCreditSubscription` (lines 127-139) -- invalidates `organizationAiCreditPurchase` + `organizationAiCreditBalance` |
| Frontend modal | `app/javascript/ats/src/views/accountAdmin/accountBilling/CancelAiCreditSubscriptionConfirmModal.tsx` | Props: `onCancel`, `onConfirm`, `isLoading`, `periodEndsAt`. Button: `disabled={isLoading}` |

### Credit granting analog (`ApplyAiCreditPurchase`)

| Layer | File | Pattern |
|-------|------|---------|
| Interactor | `app/interactors/apply_ai_credit_purchase.rb` | `ApplicationRecord.transaction` block; stamp `stripe_invoice_id` for idempotency; `finalize_stripe_payment`; create `AiCreditBalanceTransaction` with `save` (not `save!`); check return and `fail_with_record_invalid`; reset balance notification flags |

### Webhook routing analog (existing `invoice.paid` handler)

| Layer | File | Pattern |
|-------|------|---------|
| Job | `app/jobs/stripe_webhook_handler_job.rb` | `handle_subscription_credit_pack_invoice_paid` (lines 472-490): find purchase by `stripe_subscription_id`, stamp payment info, call `ApplyAiCreditPurchase.call` |
| Downgrade handler | `app/jobs/stripe_webhook_handler_job.rb` | `handle_subscription_schedule_downgrade` (lines 342-401): checks phases, detects downgrade, fires Discord + engagement report jobs |

### Modal component analogs

| Analog | File | Pattern |
|--------|------|---------|
| Cancel modal | `app/javascript/ats/src/views/accountAdmin/accountBilling/CancelAiCreditSubscriptionConfirmModal.tsx` | `CenterModal` + `headerTitleText` + `onCancel`; `Button` with `disabled={isLoading}`; `const Styled: any = {}` pattern; 72 lines |
| Top-up modal | `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/PurchaseAiCreditTopUpConfirmModal.tsx` | Same `CenterModal` pattern but NO `isLoading`/`disabled` on confirm button; `const Styled: any = {}` pattern; 61 lines |

---

## Angle 1: Stripe API contract -- preview params must match commit params

**What it covers:** The core guarantee of approved decision #2: what the user saw in the modal is what Stripe charges. The `Stripe::Invoice.create_preview` params in `preview_subscription_change` must be identical to the `Stripe::Subscription.update` params in `commit_subscription_change`. Any mismatch means the confirmation modal showed wrong amounts.

**Specific checks:**
- Both calls use the same `items` array structure (same `id`, same `price`)
- Both use `proration_behavior: 'always_invoice'`
- Both use `proration_date: organization_ai_credit_purchase.subscription_current_period_start.to_i`
- The `subscription_details` wrapper on the preview call maps correctly to the flat params on the update call (Stripe API difference: `create_preview` nests under `subscription_details`, `Subscription.update` takes flat params)
- The subscription item ID is extracted the same way in both actions (from `stripe_subscription.items.data.first.id`)
- The `determine_price_id` method is called the same way in both actions

**Files to review:**
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` -- both new actions
- Stripe API documentation for `Invoice.create_preview` vs `Subscription.update` param shapes

**Analog files for comparison:**
- Same controller, `change_subscription_portal_session` (lines 233-281) -- the old flow's Stripe API call pattern
- Same controller, `cancel` action -- error handling pattern

**Convention context:**
- `cursor_rules/core_critical_rules.md` rule 1: no begin blocks in controllers
- `cursor_rules/core_critical_rules.md` rule 8: guard clauses with bare return
- Spec constraint C3: preview and commit params must match exactly
- Spec constraint C10: `determine_price_id` reuse

---

## Angle 2: Webhook event routing -- `billing_reason` branching in `invoice.paid`

**What it covers:** The `handle_subscription_credit_pack_invoice_paid` method is modified to check `invoice.billing_reason` before dispatching to credit granting. The routing must be correct for all three billing reasons: `subscription_update` (upgrade proration), `subscription_cycle` (renewal), and `subscription_create` (first invoice). A routing error means credits are granted wrong -- either double-granting full credits on upgrade, or granting the difference on renewal.

**Specific checks:**
- The `billing_reason` check is placed AFTER the purchase lookup and payment-info stamp (those apply to all invoice types)
- The `billing_reason` check is placed BEFORE the `ApplyAiCreditPurchase.call` dispatch
- `'subscription_update'` routes to `ApplyAiCreditUpgrade.call`
- `'subscription_cycle'` and `'subscription_create'` route to `ApplyAiCreditPurchase.call` (existing behavior preserved)
- No other `billing_reason` values are possible for credit-pack subscription invoices (confirm this against Stripe docs or the real invoice example)
- The guard ordering (known failure pattern #8): no guard between method entry and the new branch that would reject the upgrade invoice

**Files to review:**
- `app/jobs/stripe_webhook_handler_job.rb` -- `handle_subscription_credit_pack_invoice_paid` method and the `invoice.paid` dispatch chain above it (lines 222-306 for routing, lines 472-490 for the handler)
- `stripe-invoice-subscription-update-example.json` -- real invoice structure confirmation

**Analog files for comparison:**
- `app/jobs/stripe_webhook_handler_job.rb` -- existing `handle_subscription_credit_pack_invoice_paid` (the exact method being modified)
- `app/jobs/stripe_webhook_handler_job.rb` -- `invoice.paid` routing dispatch (lines 222-306) for the metadata-based routing pattern

**Convention context:**
- Known failure pattern #8: webhook handlers -- trace guard ordering before adding new branches
- Spec constraint C1: credits granted on `invoice.paid` only, never on `customer.subscription.updated`
- Spec constraint C2: invoice `billing_reason` distinguishes invoice types

---

## Angle 3: Credit granting correctness -- `ApplyAiCreditUpgrade` interactor

**What it covers:** The new `ApplyAiCreditUpgrade` interactor must correctly extract old/new lookup keys from invoice line items, compute the credit difference, and grant exactly that difference. This is the most financially sensitive piece -- wrong math means customers get too many or too few credits.

**Specific checks:**
- Line item extraction: negative-amount line = old plan, positive-amount line = new plan. Confirm against `stripe-invoice-subscription-update-example.json` (the real invoice has exactly this structure: line 65 `amount: -83727`, line 181 `amount: 156777`)
- Lookup key extraction: `line.price.lookup_key` path matches the real invoice structure (line 132: `lookup_key` is nested under `price`)
- Credit lookup: `OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key` is the correct class method (confirmed it exists in the model, lines ~87-95)
- Difference calculation: `new_credits - old_credits` (must be positive for upgrades)
- Guard: non-positive difference is rejected (prevents granting on downgrades that somehow reach this path)
- Idempotency: `stripe_invoice_id == invoice.id` check prevents double-granting
- Transaction block: matches `ApplyAiCreditPurchase` pattern (stamp `stripe_invoice_id`, `finalize_stripe_payment`, create `AiCreditBalanceTransaction`, reset notification flags)
- Entry type: `subscription_credit_pack_purchase_credit` (value 30) -- same as renewal grants
- Bucket: `addon_subscription` (value 2) -- same as renewal grants
- The `AiCreditBalanceTransaction` validation rule `entry_type_and_amount_valid` requires credits to be positive -- confirm `credit_difference` is always positive when this path is reached
- Description string distinguishes upgrade grants from renewal grants (auditable in the ledger)
- Does NOT update `subscription_status`, period dates -- those are handled by `customer.subscription.updated` webhook (confirmed the existing handler at lines 111-165 already does this)

**Files to review:**
- `app/interactors/apply_ai_credit_upgrade.rb` (new file)
- `app/models/ai_credit_balance_transaction.rb` -- `entry_type` enum (line 30: value 30), `bucket` enum (line 38: value 2), validation rules
- `app/models/organization_ai_credit_purchase.rb` -- `ai_credit_allocation_for_lookup_key` class method, `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` constant, `finalize_stripe_payment` method (lines 156-158)
- `stripe-invoice-subscription-update-example.json` -- real invoice line item structure

**Analog files for comparison:**
- `app/interactors/apply_ai_credit_purchase.rb` -- the renewal/first-invoice credit granting interactor. Structural manifest comparison:
  - Transaction block: SAME pattern expected
  - Idempotency check: SAME (`stripe_invoice_id`)
  - `finalize_stripe_payment` call: SAME
  - Balance notification flag reset: SAME
  - Credit amount source: DIFFERENT -- `subscription_credits_per_period` (analog) vs `credit_difference` (new)
  - Purchase field updates: DIFFERENT -- analog updates `subscription_status`, period dates; new interactor does NOT (spec says `customer.subscription.updated` handler does this)
  - `fail_with_record_invalid` helper: SAME pattern

**Convention context:**
- `cursor_rules/core_critical_rules.md` rule 11: no bang methods
- `cursor_rules/core_critical_rules.md` rule 12: always check save/update return values
- Variable naming rule: `organization_ai_credit_purchase` not `purchase`, `ai_credit_balance_transaction` not `transaction`
- Spec constraint C7: variable naming
- Known failure pattern #13: never fabricate fallback values for absent data

---

## Angle 4: Downgrade scheduling -- `ScheduleAiCreditSubscriptionDowngrade` interactor and webhook lifecycle

**What it covers:** The downgrade flow creates a `Stripe::SubscriptionSchedule` that transitions the subscription at period end. This involves a multi-step Stripe API sequence (create schedule from subscription, then update with phases) and relies on existing webhook handlers (`subscription_schedule.updated`, `customer.subscription.updated`, `invoice.paid`) to handle the downstream lifecycle. The interactor must not update local state directly -- the webhook handlers do that.

**Specific checks:**
- `Stripe::SubscriptionSchedule.create(from_subscription: ...)` is called with the correct subscription ID
- Phase 1 preserves the current price with correct `start_date`/`end_date` from the purchase's period dates
- Phase 2 uses the new (lower) price with `iterations: 1`
- `end_behavior: 'release'` allows the subscription to continue after the schedule completes
- The interactor does NOT update any purchase fields directly -- confirmed by spec ("the `subscription_schedule.updated` webhook handler already handles that")
- Error path: `Stripe::StripeError` fails the context with `:stripe_error`, local state untouched (Stripe-first pattern from `CancelAiCreditSubscription` analog)
- Edge case: what if the subscription already has a pending schedule? The spec notes "the create call may need to update the existing schedule instead" -- review must check if this is handled
- The existing `handle_subscription_schedule_downgrade` (lines 342-401 in webhook handler) correctly handles the `subscription_schedule.updated` event fired by this interactor -- it detects the downgrade and fires Discord/engagement report jobs
- At period end: Stripe automatically transitions, `customer.subscription.updated` fires with new price (updates purchase row), then `invoice.paid` fires with `billing_reason: 'subscription_cycle'` (grants credits at new lower amount via existing `ApplyAiCreditPurchase`)

**Files to review:**
- `app/interactors/schedule_ai_credit_subscription_downgrade.rb` (new file)
- `app/jobs/stripe_webhook_handler_job.rb` -- `handle_subscription_schedule_downgrade` (lines 342-401), `subscription_schedule.updated/created` dispatch (lines 326-328)
- `app/models/organization_ai_credit_purchase.rb` -- `subscription_current_period_start`, `subscription_current_period_end` columns

**Analog files for comparison:**
- `app/interactors/cancel_ai_credit_subscription.rb` -- Stripe-first pattern, `context.fail!` on Stripe error, method-level rescue
- `app/services/stripe/cancel_credit_pack_subscription.rb` -- thin Stripe API wrapper pattern (the new interactor makes the Stripe call directly rather than through a service, which is a deviation from the cancel flow -- review whether this is acceptable or whether a service wrapper is warranted)

**Convention context:**
- Known failure pattern #14: analog structural matching -- compare signatures, not just layers
- Spec: "If the subscription already has a pending schedule, the create call may need to update the existing schedule instead" -- this is an explicit TBD in the spec

---

## Angle 5: Frontend data flow -- preview response to modal props to commit mutation

**What it covers:** The preview response from the backend must flow correctly through `handleSelectTier` into the modal's props, and the commit mutation must fire with the correct params when the user confirms. This angle traces every prop on `UpdateAiCreditSubscriptionConfirmModal` back to the preview response to verify nothing is lost, misformatted, or fabricated.

**Specific checks:**
- Preview response shape matches the TypeScript `PreviewSubscriptionChangeResponse` interface
- `amountDue` (cents) is formatted to dollars correctly (`Math.abs(cents) / 100` with `toFixed(2)`)
- `lines` array: negative line = old plan credit, positive line = new plan charge (same extraction as backend)
- `currentPeriodEnd` (unix timestamp) is formatted via `prettyDate` from `@shared/lib/time`
- `defaultPaymentMethod`: brand is capitalized (first letter uppercase), last4 is appended. Null is handled (empty string, not a crash)
- `newPlanName` from `AI_CREDIT_PACK_DISPLAY_NAMES[tier.lookupKey]` -- confirm the constant has entries for all credit-pack lookup keys (both production and development)
- `newPlanCredits` from `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY[tier.lookupKey]` -- same confirmation
- `isDowngrade` computed from `currentCredits != null && tier.credits < currentCredits` -- same logic in `aiSubscriptionHelpers.ts` `deriveTierButtonText`
- The modal receives `isLoading={isCommittingChange}` -- confirm the modal passes this to the confirm Button as `disabled` (known failure pattern #11: copy behavioral props)
- `onConfirm` closure calls `commitSubscriptionChange` with `{ priceId: tier.priceId, isDowngrade }` -- confirm `priceId` matches what preview used
- Query invalidation on success: `organizationAiCreditPurchase`, `organizationAiCreditBalance`, `aiCreditCustomerSubscription` -- confirm these are the correct query keys (compare with cancel hook which invalidates `organizationAiCreditPurchase` + `organizationAiCreditBalance`)
- Error toast pattern: `error?.data?.errors?.general?.[0]` fallback matches the existing pattern in `AiCreditSubscription.tsx`
- `removeModal()` is called on both cancel and confirm-success paths

**Files to review:**
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx` (new file)
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` -- `handleSelectTier` replacement
- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` -- new hooks
- `app/javascript/shared/lib/planHelpers.ts` -- `AI_CREDIT_PACK_DISPLAY_NAMES`, `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` constants

**Analog files for comparison:**
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` -- existing `handleSelectTier` (lines 158-170), `handleChangeSubscriptionViaStripePortal`, `handleUpdateWithPaymentMethod` for the old flow's data passing pattern
- `app/javascript/ats/src/views/accountAdmin/accountBilling/CancelAiCreditSubscriptionConfirmModal.tsx` -- modal prop interface, `disabled={isLoading}` on confirm Button, CenterModal usage
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/PurchaseAiCreditTopUpConfirmModal.tsx` -- modal prop interface, Styled pattern

**Convention context:**
- `cursor_rules/core_critical_rules.md` rule 7: backend snake_case, frontend camelCase (API layer transforms automatically)
- `cursor_rules/core_critical_rules.md` rule 9: never deliberately set undefined
- `cursor_rules/core_critical_rules.md` rule 10: never fabricate fallback values
- Known failure pattern #1: emotion theme utilities are complete CSS declarations
- Known failure pattern #11: analog replication -- copy behavioral props, not just layout
- Known failure pattern #12: styled components -- use separate components for visual variants, not conditional props
- Known failure pattern #13: never fabricate fallback values for absent data
- Spec constraint C5: handoff file is visual reference only -- all identifiers from codebase
- Spec constraint C6: no `hasUnsavedChanges` on the modal

---

## Angle 6: Complete removal of portal flow -- no orphaned code

**What it covers:** Three controller actions, three routes, two frontend mutation hooks, two frontend handler functions, and one redirect function are being removed. Incomplete removal leaves dead code, broken imports, or unreachable routes. This angle verifies that every reference to the old flow is removed and nothing new accidentally depends on it.

**Specific checks:**
- Controller: `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session` are all deleted (not just commented out)
- Routes: all three route lines removed from `config/routes.rb`
- Frontend hooks: `changeAiCreditSubscriptionViaStripePortal`, `useChangeAiCreditSubscriptionViaStripePortal`, `updateAiCreditSubscriptionWithPaymentMethod`, `useUpdateAiCreditSubscriptionWithPaymentMethod` removed from `useOrganizationAiCreditPurchase.ts` AND from its export block
- Frontend component: `handleChangeSubscriptionViaStripePortal`, `handleUpdateWithPaymentMethod`, `redirectToStripe` removed from `AiCreditSubscription.tsx`
- Imports: the old hooks are no longer imported in `AiCreditSubscription.tsx`
- No other file in the codebase imports or references the removed hooks or controller actions (grep for all removed identifiers)
- The `stripeDefaultPaymentMethodOnFile` check in `handleSelectTier` is removed (no longer needed -- the new flow doesn't fork on payment method presence)
- Spec files: any existing specs for the removed actions should also be removed (known failure pattern #6: rename cascades -- grep for ALL references including spec files)

**Files to review:**
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` -- confirm removal of three actions
- `config/routes.rb` -- confirm removal of three routes
- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` -- confirm removal of two hooks + functions + exports
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` -- confirm removal of old handlers + `redirectToStripe` + imports
- `spec/controllers/api/v1/organization_ai_credit_purchases_controller_spec.rb` (if exists) -- confirm removal of specs for deleted actions
- Grep across entire codebase for: `change_subscription_portal_session`, `update_payment_method_and_subscription_portal_session`, `continue_change_subscription_portal_session`, `changeAiCreditSubscriptionViaStripePortal`, `updateAiCreditSubscriptionWithPaymentMethod`, `redirectToStripe`

**Analog files for comparison:** N/A (this is removal verification, not structural comparison)

**Convention context:**
- Known failure pattern #6: rename cascades -- grep for ALL references, including spec files

---

## Angle 7: Analog structural matching -- new code matches existing patterns

**What it covers:** The new controller actions, interactors, mutation hooks, and modal component must match the structural patterns of their analogs -- not just have the same layers, but the same shapes. This angle performs the structural manifest comparison required by known failure pattern #14.

**Specific checks:**

**Controller actions (`preview_subscription_change`, `commit_subscription_change`) vs analogs:**
- Authorization: `authorize :billing, :change_subscription?` matches the portal actions (same policy method)
- Purchase lookup: same query as `cancel`, `change_subscription_portal_session`, etc.: `current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])`
- Guards: same guard pattern as `change_subscription_portal_session` (raise StandardError for missing customer, missing subscription, missing subscription_id)
- Error handling: method-level `rescue Stripe::StripeError => e` with `Rails.logger.error`, `ap e`, `Sentry.capture_exception(e, extra: {...})`, `render_general_errors` -- exact same shape as `cancel` and portal actions
- Response: `render_one(organization_ai_credit_purchase.reload, Api::V1::OrganizationAiCreditPurchaseSerializer)` for commit (matches `cancel` response pattern); custom JSON for preview (no analog -- new response shape)
- No begin blocks (core critical rule 1)
- Single quotes (constraint C9)

**`ApplyAiCreditUpgrade` vs `ApplyAiCreditPurchase`:**
- Both include `Interactor`
- Both have `def call` as entry point
- Both wrap credit operations in `ApplicationRecord.transaction`
- Both stamp `stripe_invoice_id` for idempotency
- Both call `finalize_stripe_payment`
- Both create `AiCreditBalanceTransaction` with `save` (not `save!`) and check return
- Both call `fail_with_record_invalid` on failure
- Both reset balance notification flags
- EXPECTED DIFFERENCE: amount source (`credit_difference` vs `subscription_credits_per_period`)
- EXPECTED DIFFERENCE: no `subscription_status`/period updates (handled by `customer.subscription.updated`)
- Variable naming: `organization_ai_credit_purchase` (not `purchase`) -- NOTE: `CancelAiCreditSubscription` uses `purchase` which violates the naming rule; the new interactor must NOT copy this violation

**`ScheduleAiCreditSubscriptionDowngrade` vs `CancelAiCreditSubscription`:**
- Both include `Interactor`
- Both make Stripe API call first, then update local state (or don't, in the downgrade case)
- Both rescue `Stripe::StripeError` and `context.fail!` with `:stripe_error`
- EXPECTED DIFFERENCE: cancel updates local purchase fields; downgrade does NOT (webhooks handle it)
- DEVIATION TO CHECK: cancel uses a service wrapper (`Stripe::CancelCreditPackSubscription`); downgrade makes Stripe calls directly in the interactor. Is this acceptable?

**Mutation hooks vs existing hooks in `useOrganizationAiCreditPurchase.ts`:**
- `apiPost` with `path` and `variables` pattern
- `useMutation` wrapper
- `onSuccess` callback with `queryClient.invalidateQueries`
- Query keys invalidated: compare with cancel hook (`organizationAiCreditPurchase` + `organizationAiCreditBalance`) and portal hooks (`currentOrganization` + `organizationAiCreditPurchase`). The new commit hook adds `aiCreditCustomerSubscription` -- verify this is needed
- Export from the export block

**Modal component vs cancel/top-up modal:**
- `CenterModal` with `headerTitleText` and `onCancel` -- matches both analogs
- `Styled` object pattern -- both analogs use `const Styled: any = {};` (the spec says `let Styled: any; Styled = {};` -- check which pattern is used in the implementation and whether it matches the analogs)
- `Button` with `disabled={isLoading}` on confirm -- matches cancel modal, does NOT match top-up modal (which has no loading state). The new modal SHOULD have loading state per known failure pattern #11
- Theme access: `const t: any = props.theme;` inside styled components

**Files to review:** All new and modified files listed in subsystems touched section

**Analog files for comparison:** All analog files listed in the full-stack analog section

**Convention context:**
- Known failure pattern #14: analog structural matching -- compare signatures, not just layers
- Known failure pattern #11: analog replication -- copy behavioral props, not just layout
- Variable naming rule (global CLAUDE.md + core_critical_rules.md)
- Spec section "Existing patterns to follow"

---

## Angle 8: Authorization and error surface

**What it covers:** Both new controller actions must be properly authorized and all error paths must produce user-visible feedback, not silent failures or 500s. This angle checks authorization, Stripe error handling, guard validation, and frontend error display.

**Specific checks:**

**Authorization:**
- Both actions call `authorize :billing, :change_subscription?`
- `BillingPolicy#change_subscription?` requires `is_org_admin?` (confirmed in `billing_policy.rb` line 24)
- Non-admin users get 403 (Pundit default behavior)
- No new policy methods needed (spec confirms)

**Backend error paths:**
- Missing Stripe customer ID: `raise StandardError` with descriptive message
- No active subscription purchase: `raise StandardError` (or similar guard)
- Missing `stripe_subscription_id`: `raise StandardError`
- `Stripe::StripeError` during preview: rescued, logged (`Rails.logger.error`, `ap`, `Sentry.capture_exception`), rendered via `render_general_errors`
- `Stripe::StripeError` during commit (upgrade): same rescue pattern
- `Stripe::StripeError` during commit (downgrade): caught by interactor, returned as context failure, controller renders error
- Missing `price_id` param: `determine_price_id` raises (existing behavior)
- `ApplyAiCreditUpgrade` failures: missing balance, unrecognized lookup keys, non-positive credit difference -- all should log and `context.fail!` (but these happen asynchronously via webhook, not in the controller request cycle)

**Frontend error paths:**
- Preview failure: `onError` callback shows toast with `error?.data?.errors?.general?.[0]` fallback
- Commit failure: `onError` callback shows toast with same pattern
- Error toast uses `delay: 30000` (30 seconds) matching existing pattern
- No silent failures: every mutation has both `onSuccess` and `onError` handlers

**Files to review:**
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` -- new actions
- `app/policies/billing_policy.rb` -- `change_subscription?` method
- `app/interactors/apply_ai_credit_upgrade.rb` -- failure paths
- `app/interactors/schedule_ai_credit_subscription_downgrade.rb` -- failure paths
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` -- error handling in `handleSelectTier`

**Analog files for comparison:**
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` -- `cancel` action error handling (lines 209-226)
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` -- portal action error handling (lines 271-281)

**Convention context:**
- `cursor_rules/core_critical_rules.md` rule 1: no begin blocks
- `cursor_rules/core_critical_rules.md` rule 8: guard clauses with bare return (for non-exception guards)
- General principles: rescue the most specific error class possible; always log errors with context; never leave rescue blocks empty

---

## Always-on checks

These apply to every review angle and every file:

1. **Variable naming (global rule + core_critical_rules.md):** Every database-backed record variable uses the full model name in snake_case. `organization_ai_credit_purchase` not `purchase`. `ai_credit_balance_transaction` not `transaction`. `organization_ai_credit_balance` not `balance` (unless used as shorthand within a method where the model is unambiguous, following the existing `ApplyAiCreditPurchase` pattern).

2. **No begin blocks in controllers (core_critical_rules.md rule 1):** All controller error handling uses method-level rescue.

3. **Single quotes in Ruby (spec constraint C9):** All string literals use single quotes unless interpolation is needed.

4. **No bang methods (core_critical_rules.md rule 11):** No `save!`, `update!`, `create!` outside of specs.

5. **Check save/update return values (core_critical_rules.md rule 12):** Every `save` or `update` call has its return value checked.

6. **No fabricated fallback values (core_critical_rules.md rule 10, known failure pattern #13):** No `|| 0`, `|| ""`, `|| []` that substitutes a non-nil value for absent data. `|| ''` is acceptable only in `useState` initializers.

7. **Never deliberately set undefined (core_critical_rules.md rule 9):** No explicit `undefined` assignments in TypeScript.

8. **Theme colors verified (core_critical_rules.md rule 2):** Any color used in styled components exists in `app/javascript/ats/styles/theme.ts`.

9. **Emotion theme utilities are complete CSS declarations (known failure pattern #1):** `t.text.sm` etc. used standalone, not inside a `font-size:` property.

10. **Styled components: separate components for visual variants (known failure pattern #12):** No custom boolean props passed to styled HTML elements.

11. **Backend snake_case, frontend camelCase (core_critical_rules.md rule 7):** API layer transforms automatically. Ruby enum values stay snake_case on frontend.

12. **No `hasUnsavedChanges` on the modal (spec constraint C6):** The CenterModal omits this prop.

13. **Handoff file is visual reference only (spec constraint C5):** All identifiers, imports, hooks, and data flow come from the codebase, not from the handoff file at `~/Projects/genuine-article-images/UpdateSubscriptionConfirmModal.tsx`.

14. **Test requirements covered (known failure pattern #3):** The spec includes a test requirements section. Review must verify all listed specs are present and cover the specified scenarios.

15. **Guard clause bare returns (core_critical_rules.md rule 8):** Guard clauses use bare `return`, not `return false`/`return nil`/`return true`.
