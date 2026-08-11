# AI Settings Redesign — Handoff Audit & Implementation Plan

**Date:** 2026-06-15
**Branch:** `ai-frontend-work`
**Handoff source:** `/Users/jessica/Projects/genuine-article-images/handoff/`

---

## Audit: Rule Violations & Data Mismatches

### CRITICAL — Data shape mismatches

**1. Balance type doesn't match handoff's three-bucket model**

Real `OrganizationAiCreditBalance` type (`shared/types/organizationAiCreditBalance.ts`):
```
id, dailyCreditsRemaining, monthlyCreditsRemaining,
addonSubscriptionCreditsRemaining, addonCreditsRemaining,
totalCreditsRemaining, monthlyCreditAllocation, currentPeriodEndAt
```

Handoff assumes:
- `planCreditAllocation` / `planCreditsRemaining` — **don't exist**
- `monthlyCreditAllocation` / `monthlyCreditsRemaining` — exist ✅
- `addonCreditsRemaining` — exists ✅

The "plan-included credits" bucket doesn't exist as a separate field. The real type has `dailyCreditsRemaining` and `addonSubscriptionCreditsRemaining` instead. The three-bucket meter design (`AiCreditBalance` / `AiCreditMeter`) needs to map to real fields.

**2. Prices payload shape mismatch**

`aiCreditPrices()` returns:
```
{ lookupKey, kind, credits, priceId, priceDollars, currency, interval }
```

Handoff assumes:
```
{ lookupKey, kind, credits, name, blurb, price }
```

Missing: `name`, `blurb` (don't exist in payload). Wrong field: `price` → `priceDollars`. Extra real fields: `priceId`, `currency`, `interval`.

**3. Subscription status type mismatch**

Real: `"active" | "past_due" | "canceled" | "paused"`
Handoff mock: `"active" | "inactive" | null`

`isSubscribed` check in `AiCreditSubscription` uses `=== "active"` which is correct, but the mock data and types need updating.

### CLAUDE.md Rule Violations

**4. Nullish coalescing `??`** (Rule 11)
- `AiCreditSubscription.tsx`: `subscription?.subscriptionCreditsPerPeriod ?? null`
- Fix: `subscription?.subscriptionCreditsPerPeriod || null`

**5. Multi-line comment blocks** (CLAUDE.md: "default to writing no comments")
- Every handoff file has JSDoc `/** */` blocks — remove all.

**6. Error handler pattern wrong** (`OrganizationAiSettings.tsx`)
- Uses `(data as any).errors` — should be `(response: any) => { setErrors(response.data.errors); }`
- Uses `kind: "danger"` — codebase convention is `kind: "warning"` for mutation errors.

**7. Missing error clearing on input change** (`OrganizationAiSettings.tsx`)
- `updateSettingState` doesn't call `setErrors(null)` — cursor rules require clearing errors when user edits.

### Import Path Issues

**8. `CancelAiCreditSubscriptionConfirmModal`**
- Exists at `accountBilling/CancelAiCreditSubscriptionConfirmModal.tsx`
- Handoff imports from `./` (current directory) — needs real relative path

**9. `AiCreditBalanceDisplay`**
- Referenced by current `OrganizationAiUsage.tsx` — lives in `accountBilling/`
- Being replaced by `AiCreditBalance.tsx` — correct

### Grounded / Verified ✅

- `SmallButton` exists at `components/shared/SmallButton.tsx`
- `SettingsContainer` accepts `fullWidthForm` prop
- `aiCreditPrices` exists in `@shared/lib/planHelpers`
- `prettyDate` exists in `@shared/lib/time`
- All five query hooks exist and export correctly from `useOrganizationAiCreditPurchase.ts`
- `CancelAiCreditSubscriptionConfirmModal` exists
- Container pattern (NavItem sidebar, UnsavedChangesGuard, Switch/Route) matches `AccountJobBoardContainer`
- FormSelect, FormInput, FormConditionalFields all used correctly
- Theme mixins match codebase patterns

---

## Implementation Plan

### Phase 1: Fix handoff files and write to codebase

All files go to `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/` unless noted.

#### 1a. AccountPlatoAiContainer.tsx (REPLACE existing)
- Remove JSDoc comment
- Remove `Styled.List` wrapper (put `margin-top` on `Styled.Sidebar` like current)
- Keep nav order: Billing / Usage / Settings (billing first = landing route)
- Keep `Redirect to billing`
- Keep `LoadingIndicator` guard for `currentOrganization`

#### 1b. OrganizationAiBilling.tsx (REPLACE existing in `accountAdmin/`)
- Remove JSDoc comment
- Thin wrapper: `SettingsContainer` + `<AiCreditSubscription />`
- Keep `fullWidthForm={true}`

#### 1c. AiCreditSubscription.tsx (NEW — in `accountPlatoAi/`)
- Remove JSDoc comment
- Fix `??` → `||`
- Fix import path for `CancelAiCreditSubscriptionConfirmModal` (relative to `accountBilling/`)
- Fix `splitTiers` to use real payload shape (no `name`, `blurb` — use `lookupKey` to derive display name)
- `subscriptionTiers` and `topUpTiers` use real `aiCreditPrices()` output shape
- No mock data — real hooks only

#### 1d. AiSubscriptionTierCard.tsx (NEW — in `accountPlatoAi/`)
- Remove JSDoc comment
- Interface `AiCreditTier` must match real payload: `lookupKey`, `credits`, `priceDollars`, `kind`, `interval`
- `name` derived from lookup key or added as display mapping
- `price` → `priceDollars`
- Remove `blurb` (not in payload)

#### 1e. AiCreditPackCard.tsx (NEW — in `accountPlatoAi/`)
- Remove JSDoc comment
- Interface `AiCreditPack` matches real payload shape
- `price` → `priceDollars`

#### 1f. OrganizationAiUsage.tsx (REPLACE existing in `accountAdmin/`)
- Remove JSDoc comment
- Replace `AiCreditBalanceDisplay` with `AiCreditBalance`
- Map real balance fields to meter component
- Add "Buy more credits" CTA linking to billing tab

#### 1g. AiCreditBalance.tsx (NEW — in `accountPlatoAi/`)
- Remove JSDoc comment
- Map to real `OrganizationAiCreditBalance` fields:
  - Meter 1: "Monthly credits" — `monthlyCreditsRemaining` / `monthlyCreditAllocation`
  - Meter 2: "Subscription credits" — `addonSubscriptionCreditsRemaining` (no total — show as "available")
  - Meter 3: "Top-up credits" — `addonCreditsRemaining` (no total — show as "available")
- Drop the `planCredit*` bucket (doesn't exist)

#### 1h. AiCreditMeter.tsx (NEW — in `accountPlatoAi/` or `components/shared/`)
- Remove JSDoc comment
- Otherwise structurally sound — keep as-is

#### 1i. aiSubscriptionHelpers.ts (NEW — in `accountPlatoAi/`)
- Fix `splitTiers` to use real `aiCreditPrices()` output (no `name`/`blurb`)
- `AiPrice` interface matches real payload: `{ lookupKey, kind, credits, priceId, priceDollars, currency, interval }`
- `formatResetDate` uses `prettyDate` — correct

#### 1j. OrganizationAiSettings.tsx (REPLACE existing in `accountAdmin/`)
- Remove JSDoc comment
- Fix error handler: `(response: any) => { setErrors(response.data.errors); }`
- Fix toast kind: `"danger"` → `"warning"`
- Add error clearing in `updateSettingState`
- Switch from `FormCheckbox` to `FormSelect` with enabled/disabled options (design decision)
- Use `FormInput` for threshold instead of custom styled input
- Keep `useEffect` resync from props

#### 1k. DELETE `aiCreditMockData.ts` — not porting mock data

### Phase 2: Verify

- Run webpack to check for compile errors
- Visual check in browser at `/hire/settings/plato-ai/billing`

---

## Decisions (resolved 2026-06-15)

1. **Three-bucket balance meters — no new backend fields needed:**
   - Plan (monthly): `monthlyCreditsRemaining` / `monthlyCreditAllocation`
   - Subscription add-on: `addonSubscriptionCreditsRemaining` (show as "available")
   - Top-up: `addonCreditsRemaining` (show as "available")
   - Total row at bottom: `totalCreditsRemaining`

2. **Tier card display names:** Hardcode a lookup map from `lookupKey` → display name in helpers. Names TBD — using placeholders for now.

3. **`dailyCreditsRemaining`** — not relevant to UI, ignore.

4. **Stub third tier:** Add a third subscription AND a third top-up to `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY`. Design for three cards, easy to drop to two later.

5. **Plan credit fields on balance type/serializer:** NOT needed. All data already served under existing field names.
