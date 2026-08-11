# Angle 5: Frontend Data Flow — Pass 1

## Summary

All major frontend claims verified against the billing-bonanza worktree. Line numbers, function names, interface fields, import paths, query keys, and behavioral claims are accurate.

## Findings

### LOW — F5-L1: `prettyDate` line number off by 1

**Plan says:** `prettyDate` at `time.ts` line 43-47 (section F.4).
**Actual:** `prettyDate` is at lines 42-46 (the `export const prettyDate =` starts at line 42, closing at line 46).
**Impact:** Negligible — the implementation agent will find the function regardless. Behavioral claim (returns `null` for null/undefined input) is correct.

## Verified claims (no findings)

### 1. `useOrganizationAiCreditPurchase.ts` — all line numbers correct
- Portal functions at lines 35-48, 50-62, 64-77, 79-91 ✓
- Cancel hook at lines 127-139 ✓
- Export block at lines 189-199 ✓
- All function and hook names spelled correctly ✓

### 2. `AiCreditSubscription.tsx` — all line numbers correct
- Imports at lines 6-14 ✓
- Portal hook destructuring at lines 36-43 ✓
- `handleUpdateWithPaymentMethod` at lines 82-117 ✓
- `handleChangeSubscriptionViaStripePortal` at lines 122-156 ✓
- `handleSelectTier` at lines 158-170 ✓
- `redirectToStripe` at lines 75-77, used at line 231 ✓
- `stripeDefaultPaymentMethodOnFile` check at line 159 (handleSelectTier) and line 250 (handleBuyPack) ✓
- Loading state at line 324 ✓

### 3. `aiSubscriptionHelpers.ts` — all line numbers correct
- `deriveTierButtonText` at lines 30-37, current logic returns "Upgrade" or "Change plan" (no "Downgrade") ✓
- `deriveTierButtonType` at lines 44-49, correctly returns "secondary" for anything that isn't "Upgrade"/"Subscribe" ✓

### 4. `planHelpers.ts` constants — both exist
- `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` at line 74 ✓ (covers prod + dev subscription + top-up keys)
- `AI_CREDIT_PACK_DISPLAY_NAMES` at line 89 ✓ (covers prod + dev subscription + top-up keys)
- `priceDollars` computed as `price.unitAmount / 100` at line 117 ✓

### 5. `prettyDate` — behavioral claim correct
- Returns `null` for `undefined` or `null` input ✓
- Returns `format(datetime * 1000, "PPP")` for valid input ✓

### 6. Cancel modal analog — all claims correct
- 73 lines ✓, CenterModal at line 5 ✓, Button at line 6 ✓
- Props at lines 9-14 (onCancel, onConfirm, isLoading?, periodEndsAt) ✓
- `disabled={isLoading}` at line 39 ✓
- `const Styled: any = {};` at line 50 ✓

### 7. Top-up modal analog — all claims correct
- 61 lines ✓, same CenterModal pattern ✓
- NO isLoading/disabled on confirm Button (line 29: bare `<Button onClick={onConfirm}>`) ✓
- `const Styled: any = {};` at line 38 ✓

### 8. `AiCreditTier` interface — all referenced fields exist
- Defined in `AiSubscriptionTierCard.tsx` lines 7-16 ✓
- Has: `name`, `credits`, `priceDollars`, `lookupKey`, `priceId`, `buttonText`, `buttonType`, `isMostPopular` ✓
- Plan references `tier.priceId`, `tier.lookupKey`, `tier.credits`, `tier.priceDollars`, `tier.name` — all present ✓

### 9. Query key strings — correct
- Cancel hook invalidates `"organizationAiCreditPurchase"` (line 135) + `"organizationAiCreditBalance"` (line 136) ✓

### 10. Icon import path — correct
- `import Icon from "@ats/src/components/shared/Icon"` confirmed at `AccountApiKeys.tsx` line 11 ✓
- Same path used in 9+ files across accountAdmin views ✓

### 11. Styled pattern — acknowledged discrepancy, not a finding
- Both modal analogs use `const Styled: any = {};` (cancel line 50, top-up line 38)
- `AiCreditSubscription.tsx` itself uses `let Styled: any; Styled = {};` (lines 356-357)
- Plan acknowledges this and follows spec directive to use `let` variant — deliberate choice ✓

### 12. `AiPrice` vs `AiCreditTier` — plan correctly references both
- `splitTiers` returns `AiPrice[]` (aiSubscriptionHelpers.ts line 20-27)
- Tier cards spread `AiPrice` into `AiCreditTier` (AiCreditSubscription.tsx line 317-321)
- `handleSelectTier` receives `AiCreditTier` — all referenced fields exist on both interfaces ✓

## Verdict

**0 BLOCKER, 0 HIGH, 0 MED, 1 LOW.** No amendments needed.
