# Investigation — Note #9: query hook consolidation → full controller restructure

## Confirmed mapping (hook → endpoint → controller)
- useAiCreditSubscription → GET /ai_credit_subscriptions → AiCreditSubscriptionsController#show
- useSubscribeToAiCreditPack → POST /ai_credit_subscriptions/subscribe → #subscribe (Stripe Checkout redirect, returns { redirectUrl })
- useCancelAiCreditSubscription → PUT /ai_credit_subscriptions/cancel → #cancel (render_one purchase)
- usePurchaseAiCreditTopUp → POST /ai_credits/purchase_top_up → AiCreditsController#purchase_top_up (Checkout redirect)
- useOrganizationAiCreditBalance → GET /ai_credits → AiCreditsController#show (render_one balance)

## Key facts
- No separate subscription model/table: OrganizationAiCreditPurchase carries `enum kind: { one_off: 0, subscription: 1 }`. Tables: organization_ai_credit_balances, organization_ai_credit_purchases, ai_credit_balance_transactions.
- Serializers already model-aligned: OrganizationAiCreditBalanceSerializer, OrganizationAiCreditPurchaseSerializer. (#11 resolves: keep both.)
- Current `ai_credit_subscriptions#show` wraps the LOCAL serializer in `{ ai_credit_subscription: <obj|null> }` (not raw Stripe). `subscribe` is Checkout-redirect (returns redirectUrl, NOT a subscription object), unlike BillingController#create_subscription (direct Stripe::Subscription.create when payment method on file).
- Hook importers of the 4 consolidated hooks: only `AccountBillingAiCredits.tsx`.
- Policy specs: only `spec/policies/ai_credit_policy_spec.rb` (no subscription policy spec; no controller/request specs for these).
- Naming convention: query hooks are singular resource per file (useJob, useCandidate, useOrganizationUser, useOrganizationAiCreditBalance); plural only for collection hooks.

## Decision: see approved-decisions.md Note #9A. Deferred: direct-create rework of subscribe (Jessica will detail separately as a future item, NOT yet specified — do not assume it is "9B").
