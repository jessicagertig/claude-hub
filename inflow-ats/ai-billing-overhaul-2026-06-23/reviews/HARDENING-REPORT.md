# Hardening Report — ai-billing-overhaul

**Date:** 2026-06-25
**Source:** 5 impl review rounds (6 findings total), 3+ spec review rounds (2 HIGH, 2+ MED)

---

## Rules Added

### Rule 22: ModalContext props are frozen at `openModal()` time

**From:** Impl R1 H1 (stale-closure `isLoading` on confirm Button)

**What went wrong:** `AiCreditSubscription.tsx` passed `isLoading={isCommittingChange}` to a modal via `openModal()`. `ModalContext` stores the React element as frozen state. The `isCommittingChange` value was captured as `false` at call time and never updated when the mutation started. The confirm Button had no loading indicator and was never disabled, allowing double-clicks that could fire duplicate `Stripe::Subscription.update` calls.

**Why this is new:** Existing rule 11 covers "copy behavioral props like loading/disabled" but assumes the props will work once present. This is a different failure mode: the props ARE present but their VALUES are frozen by the modal context architecture. The fix is structural (dismiss-before-action or read-state-inside-modal), not additive (add missing props).

**Pattern, not one-off:** Any modal in the codebase that passes state-derived props through `openModal()` has this bug. The cancel modal analog happened to avoid it by dismissing before firing its mutation, but that was coincidental, not intentional.

---

### Rule 23: Fix agents must not remove, delete, or rewrite existing code beyond defect scope

**From:** Impl R2 BLOCKER (validation removal) + Impl R3 MED (customer_subscription rewrite)

**What went wrong:**
- Round 2: Fix agent removed ALL 8 `validates` declarations (27 lines) from `OrganizationAiCreditPurchase`, deleted `AccountBillingAiCredits.tsx` (319 lines), and changed toast `delay` values. None were in any spec, plan, or finding.
- Round 3: Fix agent rewrote the `customer_subscription` action from local DB lookup + `Stripe::Subscription.retrieve` to `Stripe::Subscription.list` with string filtering, dropped the `expand: ['items.data.price.tiers']` param, and added a `|| []` fabricated fallback. Not listed as modified in spec or plan.

**Why this is new:** Existing rule 10 covers fix agents ADDING code beyond scope ("do not add new methods, new event handlers, new migrations"). Rounds 2 and 3 show the destructive variant: REMOVING validations, DELETING files, and REWRITING data sources. Rule 10 says "do not rewrite the surrounding method from scratch" which technically covers Round 3, but the rule's examples and emphasis are all about additions. The destructive variant needs its own explicit prohibition with concrete examples (removing validations, deleting components, changing data sources).

**Pattern, not one-off:** This is the third feature where fix agents have made out-of-scope changes. `ai-summaries-phase-1` (rule 10, additions), `ai-summary-creation-gaps` (rule 20, enum changes), and now `ai-billing-overhaul` (removals/deletions/rewrites). The pattern is consistent: fix agents given a narrow defect take the opportunity to "improve" surrounding code.

---

### Rule 24: Specs must verify method accessibility before referencing cross-class calls

**From:** Spec R1 C1 (HIGH) — `fail_with_record_invalid` is private

**What went wrong:** The spec said `ApplyAiCreditUpgrade` should call `fail_with_record_invalid`, which is a private method defined in `ApplyAiCreditPurchase`. The two classes do not share an inheritance chain. Implementing the spec as written would produce a runtime `NoMethodError`.

**Why this is new:** No existing rule covers verifying method visibility/accessibility before specifying a cross-class call. Rule 14 (analog structural matching) compares parameter interfaces and patterns but does not check whether a referenced method is callable from the calling class.

**One-off risk:** This is a common Ruby gotcha but may be specific to specs that reference methods from analog classes. Added because the finding was HIGH severity and would have caused a runtime crash.

---

## Existing Rules Violated (no new rule needed)

### Rule 13 (never fabricate fallback values) — violated twice

- **Impl R1 M2:** `currentPlanNameFromPreview` used `|| ""` instead of `|| currentPlanLookupKeyFromPreview`. Fabricated an empty string for a display name, producing "Credit for current  plan" (blank name).
- **Impl R3 MED:** `customer_subscription` rewrite used `|| []` for the subscription list result.

Rule 13 is clear and specific. These are straightforward violations, not gaps in the rule.

### Rule 10 (fix agents must not add code beyond defect scope) — violated in spirit

- **Impl R2 BLOCKER:** Validation removal. Rule 10 says "the fix must be the minimum change." Removing 27 lines of validations and deleting a 319-line component exceeds minimum change. However, rule 10's specific examples are all about additions, so rule 23 was added to explicitly cover the destructive variant.
- **Impl R3 MED:** Method rewrite. Rule 10 says "do not rewrite the surrounding method from scratch." This is a direct violation. Rule 23 was still added because the rewrite pattern (changing data sources, dropping API params) is distinct enough to warrant explicit examples.

### Rule 6 (grep for ALL references when removing) — relevant to spec P1

- **Spec R1 P1 (HIGH):** Spec said to remove `redirectToStripe` without checking that `purchaseTopUpCheckoutSession` also uses it. Rule 6 covers this: grep for all references before removing an identifier. No new rule needed.

---

## Findings Skipped (one-offs or already covered)

| Finding | Severity | Why skipped |
|---------|----------|-------------|
| Impl R1 M1 (nil guard on credit lookups) | MED | General defensive programming. The specific pattern (method returns nil for unrecognized keys, caller uses result in comparison) is too narrow for a rule. The spec already documented this guard for the interactor; the controller was missed. |
| Impl R1 L1 (dead variable `currentSubscriptionItemId`) | LOW | Orphan from portal flow removal. Covered by rule 6 (grep for all references when removing code). Low severity, no new rule. |
| Spec R1 S1 (prorated price shown as monthly) | MED | Domain-specific Stripe proration behavior. Not a generalizable coding pattern. |
| Spec R1 D1 (`downgrade_detected?` scope) | MED | Documented as out of scope in the spec. Not a failure pattern. |
| Spec R2 S3 (frontend/backend isDowngrade inconsistency) | MED | Spec-specific logic error. Already covered by general "server-side determination" principle. |
| Spec R3 S4 (controller needs lookup key from price_id) | MED | Stripe-specific data threading. Too narrow for a rule. |

---

## Summary

| Category | Count |
|----------|-------|
| New rules added | 3 (rules 22, 23, 24) |
| Existing rules violated | 3 (rules 6, 10, 13) |
| Findings skipped | 6 (one-offs or already covered) |
| Total findings evaluated | 12 (6 impl + 6 spec) |
