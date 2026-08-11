# Plain English Summary

## What this feature does

When an existing AI credit subscriber wants to change their plan tier (e.g., from Lite 500 credits to Plus 1000 credits), they currently get redirected to Stripe's hosted customer portal. This feature replaces that redirect with an in-app experience: a preview of what Stripe will charge, a confirmation modal, and a direct API call to Stripe.

**Upgrades** (more credits): The user sees a modal with the price difference, confirms, Stripe charges immediately, and the user gets the difference in credits added to their balance.

**Downgrades** (fewer credits): The user sees a modal explaining the change takes effect at the end of their billing period. A Stripe SubscriptionSchedule is created to transition the plan automatically at period end.

## How it works, step by step

1. User clicks a different tier card on the AI credits billing page
2. Frontend calls `preview_subscription_change` — backend calls `Stripe::Invoice.create_preview` and returns the amounts
3. Frontend shows a confirmation modal with the preview data
4. User clicks Confirm
5. Frontend calls `commit_subscription_change` — for upgrades, backend calls `Stripe::Subscription.update` with identical params to the preview; for downgrades, backend creates a `Stripe::SubscriptionSchedule`
6. For upgrades: Stripe fires `customer.subscription.updated` (updates the purchase row) and `invoice.paid` with `billing_reason: 'subscription_update'` (grants the credit difference)
7. For downgrades: Stripe fires `subscription_schedule.updated` (existing handler runs); at period end, the subscription transitions automatically

## What gets removed

Three controller actions, three routes, two frontend mutation hooks, and several handler functions that implemented the Stripe customer portal redirect flow.

---

# Blast Radius Analysis

## Files created (2)
- `app/interactors/apply_ai_credit_upgrade.rb` — new interactor for upgrade credit granting
- `app/interactors/schedule_ai_credit_subscription_downgrade.rb` — new interactor for downgrade scheduling

## Files modified (5 backend + 4 frontend = 9 total)
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — add 2 actions, remove 3 actions
- `app/jobs/stripe_webhook_handler_job.rb` — add `billing_reason` branching in `handle_subscription_credit_pack_invoice_paid`
- `config/routes.rb` — remove 3 routes, add 2 routes
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx` — new file (modal component)
- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` — add 2 hooks, remove 2 hooks + 2 functions
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` — replace handler functions, update imports/loading states
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts` — add "Downgrade" button text

## Subsystems affected
- **Stripe API**: New calls to `Invoice.create_preview`, `Subscription.update`, `SubscriptionSchedule.create/update`
- **Webhook handler**: Modified routing for `invoice.paid` based on `billing_reason`
- **Credit ledger**: New `AiCreditBalanceTransaction` records with `entry_type: 30` for upgrade grants
- **Authorization**: Uses existing `BillingPolicy#change_subscription?` (no new policies)
- **Frontend state**: React Query cache invalidation for 3 query keys on commit

## Risk areas
1. **Credit granting correctness** — wrong math means customers get too many or too few credits
2. **Webhook routing** — misrouting `subscription_update` vs `subscription_cycle` invoices would double-grant or skip grants
3. **Preview/commit param mismatch** — would show one amount and charge another
4. **Portal removal completeness** — incomplete removal leaves dead code or broken imports
5. **Downgrade schedule lifecycle** — multi-step Stripe API with webhook dependencies
