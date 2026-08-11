# Implementation Review — Failure Report

**Round:** 1
**Date:** 2026-06-25
**Verdict:** FAIL (1 HIGH, 2 MED, 1 LOW)

---

## Issues Requiring Fix

### H1 (HIGH): Stale-closure `isLoading` — confirm Button never shows loading state during commit

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:105-130`

**What's wrong:** The modal element is stored in `ModalContext` state via `openModal(<UpdateAiCreditSubscriptionConfirmModal ... isLoading={isCommittingChange} />)`. `ModalContext` (at `app/javascript/shared/context/ModalContext.tsx:28-35`) stores the React element as frozen state via `setModal(modal)` and renders it at line 83 as `{modal ? modal : null}`. The `isLoading={isCommittingChange}` prop is captured at the time `openModal` is called — inside the preview `onSuccess` callback, when `isCommittingChange` is `false`. When the user clicks Confirm, `commitSubscriptionChange` fires and `isCommittingChange` transitions to `true`, but the stored modal element's prop remains frozen at `false`. The Button's `loading` prop never activates.

**Impact:**
1. No spinner/loading indicator on the confirm button during commit
2. Button is never disabled during commit — user can double-click and fire duplicate `Stripe::Subscription.update` calls
3. Duplicate Stripe subscription updates can cause unexpected charges

**What spec/rule requires:** Known failure pattern #11 (analog replication: copy behavioral props, not just layout). The spec says the confirm Button must have `loading={isLoading}` to prevent double-clicks.

**Analog comparison:** The cancel modal at line 251-271 has the same stale-closure pattern (`isLoading={isCanceling}`) but avoids the bug because its `onConfirm` calls `removeModal()` FIRST (line 255), then fires the mutation. The modal is gone before the mutation starts, so the frozen `isLoading` never matters. The update modal does NOT call `removeModal()` first — it fires `commitSubscriptionChange(...)` while the modal is still open, relying on `isLoading` to prevent double-clicks.

**Fix:** Follow the cancel modal pattern. In the `onConfirm` closure, call `removeModal()` before `commitSubscriptionChange(...)`. The success/error feedback is already handled via `addToast`, so the modal doesn't need to stay open during the commit. This matches Decision #2 (the preview showed the authoritative amounts — the commit is a fire-and-forget confirmation).

```tsx
onConfirm={() => {
  removeModal();
  commitSubscriptionChange(
    { priceId: tier.priceId },
    {
      onSuccess: () => {
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
```

---

### M1 (MED): No nil guard on `current_credits`/`new_credits` in `commit_subscription_change`

**File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:310-314`

**What's wrong:** `OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key` returns `nil` for unrecognized lookup keys. If either `current_credits` or `new_credits` is nil, line 314 (`is_downgrade = new_credits < current_credits`) raises `NoMethodError: undefined method '<' for nil:NilClass`. The method-level `rescue Stripe::StripeError` does not catch `NoMethodError`, so the user gets a raw 500 error.

**What spec/rule requires:** The spec explicitly guards against unrecognized lookup keys in `ApplyAiCreditUpgrade` (SPEC.md lines 300-304: "Fails on unrecognized lookup keys"). The controller should have the same defensive guard. The `cancel` action analog (lines 282-298) validates the purchase state before proceeding.

**Fix:** Add a nil guard after the credit lookups:

```ruby
current_credits = OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(
  organization_ai_credit_purchase.stripe_price_lookup_key
)
new_credits = OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(new_lookup_key)

unless current_credits && new_credits
  render_general_errors(['Unable to determine credit allocation for the selected plan.'])
  return
end

is_downgrade = new_credits < current_credits
```

---

### M2 (MED): `currentPlanNameFromPreview` falls back to empty string instead of raw lookup key

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:98`

**What's wrong:** `AI_CREDIT_PACK_DISPLAY_NAMES[currentPlanLookupKeyFromPreview] || ""` uses `|| ""` as a fallback for unrecognized lookup keys. The established pattern in `planHelpers.ts` line 113 uses `|| lookupKey` to fall back to the raw lookup key so the user sees something meaningful. The `""` fallback causes the modal to display "Credit for current  plan" (blank name).

**What spec/rule requires:** Core critical rule 10 (never fabricate fallback values for absent data), known failure pattern #13 (never fabricate fallback values). The planHelpers.ts analog at line 113 shows the correct pattern.

**Fix:** Fall back to the raw lookup key:

```typescript
const currentPlanNameFromPreview = currentPlanLookupKeyFromPreview
  ? AI_CREDIT_PACK_DISPLAY_NAMES[currentPlanLookupKeyFromPreview] || currentPlanLookupKeyFromPreview
  : "";
```

The outer ternary guarding against a falsy `currentPlanLookupKeyFromPreview` can keep `""` because there genuinely is no data to display.

---

### L1 (LOW): Dead variable `currentSubscriptionItemId`

**File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:56`

**What's wrong:** `const currentSubscriptionItemId = currentSubscription && currentSubscription.items.data[0].id;` is declared but never referenced anywhere in the file. This was used by the removed portal flow (`handleChangeSubscriptionViaStripePortal` and `handleUpdateWithPaymentMethod` passed it as a param). The new flow gets the subscription item ID from the live Stripe subscription on the backend (via `stripe_subscription.items.data.first.id`), so this frontend variable is dead code.

**What spec/rule requires:** Angle 6 (portal flow removal — no orphaned code). Known failure pattern #6 (grep for ALL references when removing code).

**Fix:** Remove line 56.

---

## What NOT To Change

The following are **correct** and must not be modified:

1. **`ApplyAiCreditUpgrade` interactor** (`app/interactors/apply_ai_credit_upgrade.rb`) — Structurally matches the `ApplyAiCreditPurchase` analog exactly. All expected differences documented (no `kind` input, no period/status updates, credit_difference instead of subscription_credits_per_period). Idempotency check, transaction block, save return checks, notification flag reset all correct.

2. **`ScheduleAiCreditSubscriptionDowngrade` interactor** (`app/interactors/schedule_ai_credit_subscription_downgrade.rb`) — Stripe-first pattern correct. Phase construction correct. Does NOT update local state (webhook handles it). Variable naming correct (`organization_ai_credit_purchase`, not `purchase`).

3. **Webhook handler `billing_reason` branching** (`app/jobs/stripe_webhook_handler_job.rb:489-492`) — Routing correct: `subscription_update` to `ApplyAiCreditUpgrade`, else to `ApplyAiCreditPurchase`. Guard ordering safe (no guard rejects upgrade invoices). Placement after payment-info stamp is correct.

4. **`preview_subscription_change` controller action** — Stripe API params correct. Response shape correct. Error handling matches cancel analog. Variable naming correct.

5. **`commit_subscription_change` controller action** (except the nil guard at M1) — Server-side upgrade/downgrade determination correct. Stripe params match preview (Decision #2 / Constraint C3). Downgrade delegates to interactor with success check. Response uses `render_one` with serializer.

6. **Portal flow removal** — All three controller actions removed. All three routes removed. All four frontend hooks/functions removed. Old spec file removed. `redirectToStripe` correctly kept (still used by top-up checkout). Zero orphaned references in AI credit files (portal references in ATS billing files are expected).

7. **`UpdateAiCreditSubscriptionConfirmModal.tsx`** — Correct CenterModal usage. No `hasUnsavedChanges`. Styled object pattern matches spec (`let Styled: any; Styled = {};`). Theme colors all verified. Emotion utilities used standalone (failure pattern #1 avoided). No custom boolean props on styled elements (failure pattern #12 avoided). Button has `loading={isLoading}` prop (correct intent, just frozen by stale closure — H1 is in the calling code, not the modal itself).

8. **Mutation hooks** (`useOrganizationAiCreditPurchase.ts`) — Both new hooks follow existing patterns. `apiPost` with `path` and `variables`. `useMutation` wrapper. Commit hook invalidates `organizationAiCreditPurchase`, `organizationAiCreditBalance`, and `aiCreditCustomerSubscription` (correct — plan change updates subscription data). `PreviewSubscriptionChangeResponse` interface shape matches backend response.

9. **`deriveTierButtonText`** in `aiSubscriptionHelpers.ts` — Correctly returns "Downgrade" for lower tiers.

10. **All test files** — All spec-required test cases present. Test stubs are realistic. No ghost tests. Portal spec correctly removed.

11. **Routes** (`config/routes.rb`) — Old three routes removed. New two routes added. Correct HTTP methods (POST for both preview and commit).

---

## cursor_rules/ Violations

None found. All checked rules pass:

- Rule 1 (no begin blocks): No begin blocks in either controller action. Method-level rescue used.
- Rule 2 (theme colors): All colors in the modal verified against `theme.ts` lines 3-56.
- Rule 3 (awesome print): `ap e` used in rescue blocks, not `pp`.
- Rule 7 (snake_case backend / camelCase frontend): Backend JSON response uses `snake_case`. Frontend interfaces use `camelCase`. API layer transforms automatically.
- Rule 8 (guard clauses bare return): All guards use `render_general_errors(...)` followed by bare `return`.
- Rule 9 (never set undefined): No explicit undefined assignments in TypeScript code.
- Rule 10 (no fabricated fallbacks): Violated at M2 (`|| ""`). No violations elsewhere.
- Rule 11 (no bang methods): No `save!`, `update!`, `create!` in production code. Bang methods only in specs.
- Rule 12 (check save/update return values): All `save` and `update` calls have return values checked.
