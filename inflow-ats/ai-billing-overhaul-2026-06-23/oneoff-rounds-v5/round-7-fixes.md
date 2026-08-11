# Round 7 Fixes — AI Credit One-Off Purchase Analog Audit

Audit reported 3 deviations. All 3 fixed to match the WWR analog. Backend + frontend fixed together.

Note: the audit's cited line numbers reflect an older single-action state. The current worktree splits the one-off top-up into two controller actions (`purchase_top_up` direct-charge, `purchase_top_up_checkout_session`) and the checkout path is consumed by TWO frontend components (`AiCreditSubscription.tsx` and `AccountBillingAiCredits.tsx`). Each deviation was fixed in every live location.

---

## Deviation 1 — Checkout-session onError toast severity and fallback

ANALOG: `JobDistributionWeWorkRemotely.tsx` `handleCreateCheckoutSession` onError (lines 341-353) ALWAYS toasts `kind: "error"` with fallback `response.data.errors?.general?.[0] || "Failed to create checkout session"`. The analog's DIRECT-charge onError (`handleCreateBoardWwrListing`, lines 273-287) is different: `kind: "warning"`, only-when-`general`-defined, no fallback.

OURS routed BOTH the direct-charge and checkout-session paths through one shared `handlePurchaseError` (warning, only-when-general, no fallback). Correct for the direct-charge path, wrong for the checkout path.

FIX: Gave the checkout-session handler its own onError matching the analog's checkout onError (always toast, `kind: "error"`, fallback `"Failed to create checkout session"`). Left `handlePurchaseError` in place for the direct-charge `purchaseTopUp` (it correctly mirrors the analog's direct-charge onError).

- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` `purchaseTopUpCheckoutSession` onError (now ~199-210): inline onError, `kind: "error"`, fallback added.
- `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx` `purchaseTopUpCheckoutSession` onError (now ~138-149): inline onError, `kind: "error"`, fallback added (was `handlePurchaseError`, which used `kind: "warning"` + `delay`).

## Deviation 3 — Checkout-session frontend loading-state mechanism

ANALOG: `handleCreateCheckoutSession` manages a LOCAL `setIsPurchasing(true)` at start (line 327) and `setIsPurchasing(false)` in onError (line 342); the local `isPurchasing` flag drives button loading/disabled. OURS derived loading from the mutation hook's `isLoading` (`isPurchasingCheckoutSession`) and reset no local flag on error.

FIX (both components):
- Added `const [isPurchasing, setIsPurchasing] = React.useState(false);`
- `purchaseTopUpCheckoutSession` now calls `setIsPurchasing(true)` at start and `setIsPurchasing(false)` in onError (no reset on success — the analog redirects away).
- Stopped destructuring `isLoading: isPurchasingCheckoutSession` from `usePurchaseAiCreditTopUpCheckoutSession()`.
- To avoid a name collision, renamed the direct-charge mutation's `isLoading: isPurchasing` → `isLoading: isPurchasingDirect`.
- Updated the loading prop from `isPurchasing || isPurchasingCheckoutSession` → `isPurchasingDirect || isPurchasing` (local checkout flag now feeds the loading state).

Files: `AiCreditSubscription.tsx` (lines 46-50, 53, 290→303), `AccountBillingAiCredits.tsx` (lines 42-46, 51, 192).

## Deviation 2 — Checkout-session controller uses require-wrapped params; analog uses a separate unwrapped method

ANALOG: `BoardWwrListingsController` has TWO param methods — `listing_params` = `params.require(:board_wwr_listing).permit(...)` (direct charge) and `checkout_listing_params` = `params.permit(...)` with NO require wrapper (checkout session). The WWR checkout frontend posts FLAT params (no wrapping key).

OURS used the same `organization_ai_credit_purchase_params` (`params.require(:organization_ai_credit_purchase).permit(:stripe_price_lookup_key)`) for BOTH paths, and the checkout frontend hook posted `{ organizationAiCreditPurchase: params }` (wrapped).

FIX (backend + frontend together):
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`: added `checkout_purchase_params` = `params.permit(:stripe_price_lookup_key)` (bare permit, no require), mirroring `checkout_listing_params`. Changed `purchase_top_up_checkout_session` line 116 to read `checkout_purchase_params[:stripe_price_lookup_key]`. Left `purchase_top_up` (direct charge) on `organization_ai_credit_purchase_params` (the require-wrapped method, matching the analog's direct-charge `listing_params`).
- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`: `purchaseAiCreditTopUpCheckoutSession` now posts flat `variables: params` (was `variables: { organizationAiCreditPurchase: params }`), so `allKeysToSnake` produces flat `{ stripe_price_lookup_key }` consumed by the bare `params.permit`. This mirrors the WWR checkout frontend's flat payload.

Direct-charge hook (`purchaseAiCreditTopUp`) still posts `{ organizationAiCreditPurchase: params }` — correct, matching the analog's wrapped direct-charge payload.

---

## CANNOT-MATCH items

None.

## SUGGESTED-WHITELISTS additions

None.
