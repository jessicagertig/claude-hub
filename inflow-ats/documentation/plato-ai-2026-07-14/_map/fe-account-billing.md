# Slice: AI credits billing UI (account billing surface)

Files in `views/accountAdmin/` (the `OrganizationAiBilling.tsx` page shell + the `accountBilling/` components). The *rich* subscription/one-off/balance UI actually lives in the sibling `accountPlatoAi/` slice (another agent); this slice is the entry page shell, the handoff callout on the plan page, the billing-portal button refactor, and a set of AI-credit modal/display components (some dead).

## What changed

### New Plato AI billing page shell — `OrganizationAiBilling.tsx` (NEW)
- The `/hire/settings/plato-ai/billing` page body. Rendered inside `accountPlatoAi/AccountPlatoAiContainer.tsx`.
- On mount, parses `props.location.search`; if `ai_credit_subscribe_success` or `ai_credit_top_up_success` query params are present (Stripe checkout return), it invalidates React Query caches: `organizationAiCreditPurchase`, `organizationAiCreditBalance`, `aiCreditCustomerSubscription` — so balances/subscription refresh after a Stripe redirect back.
- Fetches `useOrganizationAiCreditPurchasePrices({refetchOnWindowFocus:false})`; shows full-page `LoadingIndicator` while fetching, then renders `SettingsContainer` (title "Plato AI billing") wrapping `accountPlatoAi/AiCreditSubscription` with `pricesData`.

### Handoff callout on the main Plan & billing page — `AiCreditsCallout.tsx` (NEW) + wired into `AccountBillingPlans.tsx` and `AccountBillingPlansUnsubscribed.tsx`
- New card at the bottom of Plan & billing: PlatoChip + "AI credits" / "Billed separately from your plan." + a "Manage AI credits" `SmallButton`.
- Rendered inside `<FeatureFlipper feature="AI_APPLICANT_SUMMARY">` — only visible when that feature flag is on.
- Button calls `history.push("/hire/settings/plato-ai/billing")`.
- NOT added to `AccountBillingPlansFreeTrial.tsx` (free-trial plan page has no callout).

### Billing-portal button refactored — `ManageBillingActions.tsx` (CHANGED, SHARED/non-AI surface)
- Previously received an `onCreateBillingPortalSession` callback prop from each parent. Now it OWNS the portal-session logic internally: calls `useCreateStripeCustomerPortalSession()` mutation directly, and accepts a new `returnUrl` prop (default `/hire/settings/billing`).
- "Manage billing" click: `trackEvent("manage_billing_clicked")` → `createStripeCustomerPortalSession({returnUrl})` → on success `window.location.href = data.redirectUrl`; on error shows a toast (`error.data.errors.general[0]` or "Unable to access billing portal.").
- Consequently the `onCreateBillingPortalSession` prop was REMOVED from `PlanCard.tsx`, `FreePlanCard.tsx`, `AccountBillingPlans.tsx`, `AccountBillingPlansFreeTrial.tsx`, `AccountBillingPlansUnsubscribed.tsx` (they no longer thread the callback down).
- The AI pages pass `returnUrl="/hire/settings/plato-ai/billing"` (from `accountPlatoAi/AiSubscriptionStatus.tsx` and `AiSubscriptionTierCard.tsx`) so the Stripe portal returns to the Plato billing page.

### `ContactUsCallout.tsx` (CHANGED, cosmetic)
- Dropped the `mb(2)` bottom margin (spacing tweak only) so the new AiCreditsCallout can sit below it.

### Dead / partially-used new components in `accountBilling/`
- `CancelAiCreditSubscriptionConfirmModal.tsx` (NEW) — USED by `accountPlatoAi/AiCreditSubscription.tsx`. Confirm modal for cancelling the AI credit subscription: body says subscription stops renewing, you keep existing credits, no further charge; shows a calendar callout "Will not renew on {formatResetDate(periodEndsAt)}". Buttons: primary "Cancel subscription" (`onConfirm`, `loading={isLoading}`), secondary "Keep subscription" (`onCancel`). Uses `formatResetDate` from `accountPlatoAi/aiSubscriptionHelpers`.
- `AiCreditPurchaseModal.tsx` (NEW) — **NOT imported anywhere** (dead code). Generic tier-picker modal (select a credit pack → "Continue to checkout").
- `AiCreditBalanceDisplay.tsx` (NEW) — **NOT imported anywhere** (dead code). Compact Monthly/Purchased/Total balance widget using `useOrganizationAiCreditBalance`. The live balance UI is `accountPlatoAi/AiCreditBalance.tsx`/`AiCreditMeter.tsx`, not this.

## User-visible behavior / actions enabled
- On Plan & billing (subscribed and unsubscribed states), an "AI credits — Manage AI credits" card appears **only if** `AI_APPLICANT_SUMMARY` flag is on; clicking navigates to the Plato AI billing page.
- The Plato AI billing page loads prices, shows a loading spinner first, then the subscription UI; returning from a successful Stripe checkout (`?ai_credit_subscribe_success` / `?ai_credit_top_up_success`) auto-refreshes balance/subscription/purchase data.
- "Manage billing" buttons (both regular billing and Plato AI pages) open the Stripe customer portal in the same tab and return to the correct page per `returnUrl`; failures surface an error toast instead of silently doing nothing.
- Cancel-subscription confirmation modal (invoked from the Plato AI subscription slice) explains credits are retained and shows the non-renewal date.

## States / edge cases
- AiCreditsCallout gated entirely by `FeatureFlipper feature="AI_APPLICANT_SUMMARY"` — flag off ⇒ card absent, no route to Plato billing from Plan & billing.
- `OrganizationAiBilling` success-refresh effect only fires when the specific query params exist; runs once on mount (`[]` deps).
- `ManageBillingActions.returnUrl` defaults to `/hire/settings/billing` if a parent omits it.

## SHARED / non-AI surfaces that could regress
- **`ManageBillingActions.tsx`** is used by the ordinary (non-AI) plan/billing cards (`PlanCard`, `FreePlanCard`) too. The portal-session flow moved from parent-supplied callback to an internal `useCreateStripeCustomerPortalSession` mutation. REGRESSION RISK: the normal "Manage billing" button on the standard Plan & billing page now depends on this internal mutation + the `returnUrl` default; verify standard (non-AI) accounts can still reach the Stripe portal and return correctly, and that error handling (toast) behaves. Also the five parent files that previously passed `onCreateBillingPortalSession` had that prop removed — confirm none still relied on the old callback path.
- **`ContactUsCallout.tsx`** margin change is shared with all Plan & billing variants (cosmetic only).

No pipeline/model/provider files in this slice.
