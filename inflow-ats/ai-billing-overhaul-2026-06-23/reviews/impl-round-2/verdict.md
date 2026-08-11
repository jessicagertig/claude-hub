# Implementation Review Round 2 -- Verdict

**Feature:** Custom AI Credit Subscription Upgrade/Downgrade
**Branch:** `billing-bonanza` (worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/`)
**Review date:** 2026-06-25
**Reviewer:** Adversarial impl review agent (Round 2)

## Verdict: FAIL

1 BLOCKER, 0 HIGH, 0 MED, 0 LOW.

---

## BLOCKER-1: Uncommitted changes include unspec'd model validation removal

**Files:**
- `app/models/organization_ai_credit_purchase.rb` (uncommitted diff)

**What happened:**
The working tree removes ALL 8 `validates` declarations from `OrganizationAiCreditPurchase` (27 lines deleted). The committed branch still has them. The spec explicitly says "No data model changes (no new columns, no new tables, no new enum values)" and the plan says nothing about validation changes. These validations enforce:

- `stripe_price_lookup_key` presence + inclusion in known lookup keys
- `kind` presence
- `stripe_subscription_id` presence (when subscription and no checkout session)
- `subscription_credits_per_period` presence + numericality (when subscription)
- `subscription_current_period_start` / `subscription_current_period_end` presence (when subscription and stripe_subscription_id present)
- `stripe_amount` presence + numericality (when not early-checkout subscription)
- `currency` presence (when not early-checkout subscription)
- `one_off_credits_granted` presence + numericality (when one_off)

Removing these validations silently allows malformed purchase records (missing currency, zero-credit one-offs, negative stripe_amount, subscription records with no period dates, etc.). Every `.save` and `.update` call in every interactor and webhook handler loses its safety net.

**Why BLOCKER (not HIGH):**
- The spec says "No data model changes." Removing 8 validations from a financial model is a data model change.
- Validations are the last line of defense for data integrity on a payment-critical model.
- This change is not committed, not spec'd, not planned, and not tested.
- Per Known Failure Pattern #10: "Fix agents must not add code beyond the defect scope." If the fix agent did this, it is out-of-scope. If it was done manually, it still needs its own spec/plan/review cycle.

**Fix:** Revert the validation removal (restore lines 87-113 of the committed model). If the validations genuinely need to change for the upgrade/downgrade feature, that change must be spec'd, planned, and reviewed separately.

---

## Round 1 Fix Verification

### H1 (stale-closure isLoading / double-click): VERIFIED CORRECT
The fix follows the cancel modal pattern exactly: `removeModal()` is called before `commitSubscriptionChange(...)` at line 108. The `isLoading={isCommittingChange}` prop is passed to the modal but will never be `true` while the modal is visible -- this matches the `CancelAiCreditSubscriptionConfirmModal` pattern at lines 249-269 which passes `isLoading={isCanceling}` identically. Success/error feedback via `addToast` fires correctly from the dismissed modal's mutation callbacks (React Query mutation callbacks survive modal unmount).

### M1 (nil guard on credit lookups): VERIFIED CORRECT
Lines 315-318 of `commit_subscription_change` add `unless current_credits && new_credits` with `render_general_errors` + bare `return`. Guard is positioned after the lookups, before the downgrade/upgrade branch. Uses bare `return` per cursor_rules rule 8.

### M2 (lookup key fallback): VERIFIED CORRECT
Line 95: `currentPlanLookupKeyFromPreview = oldLine ? oldLine.price.lookupKey : currentPlanLookupKey`. Falls back to `currentPlanLookupKey` (a raw lookup key string) rather than `""`. Line 96-98: the outer ternary `currentPlanLookupKeyFromPreview ? AI_CREDIT_PACK_DISPLAY_NAMES[...] || currentPlanLookupKeyFromPreview : ""` correctly falls through to the raw key when no display name exists, and to `""` only when no key is available at all.

### L1 (dead variable): VERIFIED CORRECT
`currentSubscriptionItemId` at old line 56 is removed. No remaining references in the file.

### Fix agent scope check (Known Failure Pattern #10): CONCERN
The uncommitted diff includes changes beyond the upgrade/downgrade feature scope:
- Model validation removal (BLOCKER-1 above)
- `AccountBillingAiCredits.tsx` deletion (319 lines removed -- a separate component, not part of any finding)
- Several `delay: 30000` additions to pre-existing toast calls (lines 167, 180, 219, 258 -- minor cosmetic changes not in any finding)

The validation removal and component deletion are NOT listed in FAILURE-REPORT.md as expected changes. The FAILURE-REPORT's "What NOT To Change" section explicitly lists interactors, webhook routing, test files, and routes as correct -- it says nothing about model validations or the AccountBillingAiCredits component.

---

## Angle-by-Angle Summary

| # | Angle | Status | Notes |
|---|-------|--------|-------|
| 1 | Stripe API contract | PASS | preview params mirror commit params; `proration_date` uses `subscription_current_period_start.to_i` consistently |
| 2 | Webhook billing_reason routing | PASS | `subscription_update` routes to `ApplyAiCreditUpgrade`; all other reasons route to `ApplyAiCreditPurchase` |
| 3 | Credit granting correctness | PASS | `ApplyAiCreditUpgrade` correctly computes `new_credits - old_credits` from invoice line items; idempotent via `stripe_invoice_id` check |
| 4 | Downgrade scheduling | PASS | `ScheduleAiCreditSubscriptionDowngrade` creates two-phase schedule via Stripe API; local state untouched (Stripe-first) |
| 5 | Frontend data flow | PASS | Preview response mapped correctly to modal props; `removeModal()` + `commitSubscriptionChange` follows cancel pattern |
| 6 | Portal flow removal | PASS | Three portal actions removed from controller/routes/hooks; new preview+commit actions replace them |
| 7 | Analog structural matching | PASS | `ApplyAiCreditUpgrade` structurally mirrors `ApplyAiCreditPurchase` (transaction, balance lookup, credit grant, notification reset, `fail_with_record_invalid` helper) |
| 8 | Authorization and error surface | PASS | `authorize :billing, :change_subscription?` on both actions; guard clauses with `render_general_errors` + bare `return`; `rescue Stripe::StripeError` with Sentry |
| A1 | Variable naming | PASS | Full model names throughout |
| A2 | No begin blocks | PASS | Method-level `rescue` only |
| A3 | Single quotes | PASS | All Ruby strings use single quotes except interpolation |
| A4 | No bang methods | PASS | Bang methods only in specs |
| A5 | Check save/update return | PASS | All `.update`/`.save` calls checked in interactors |
| A6 | No fabricated fallbacks | PASS | Round 1 M2 fix resolved the `|| ""` issue |
| A7 | Never set undefined | PASS | No deliberate `undefined` assignments |
| A8 | Theme colors | PASS | Standard palette colors |
| A9 | Emotion utilities standalone | PASS | All `t.text.*`, `t.mt()` used standalone |
| A10 | Separate styled variants | PASS | No conditional props on styled elements |
| A11 | snake_case/camelCase | PASS | Backend `snake_case`, frontend `camelCase` |
| A12 | No hasUnsavedChanges | PASS | Modal has no unsaved-changes tracking |
| A13 | Handoff visual reference | N/A | No handoff file referenced |
| A14 | Test requirements | PASS | Controller spec, interactor specs, webhook routing spec all present |
| A15 | Guard clause bare returns | PASS | All guards use bare `return` |

---

## Committed vs. Working Tree (Known Failure Pattern #15)

`git diff HEAD` run at review start. 10 files with uncommitted changes identified:
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`
- `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx`
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts`
- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`
- `app/jobs/stripe_webhook_handler_job.rb`
- `app/models/organization_ai_credit_purchase.rb`
- `config/routes.rb`
- `spec/controllers/api/v1/organization_ai_credit_purchases_change_subscription_spec.rb` (deleted)
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`

Plus 4 untracked new files:
- `app/interactors/apply_ai_credit_upgrade.rb`
- `app/interactors/schedule_ai_credit_subscription_downgrade.rb`
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx`
- `spec/controllers/api/v1/organization_ai_credit_purchases_subscription_change_spec.rb`
- `spec/interactors/apply_ai_credit_upgrade_spec.rb`
- `spec/interactors/schedule_ai_credit_subscription_downgrade_spec.rb`

The BLOCKER finding is for an uncommitted working-tree change. The feature implementation code itself (the new controller actions, interactors, modal, hooks, helpers, tests, and webhook routing) passes all angles.
