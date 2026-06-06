# Hardening Report -- AI Summaries Phase 1 Changes

**Date:** 2026-06-05 (updated after Rounds 5-6)
**Feature:** AI Summaries Phase 1 Changes
**Branch:** `feature-ai-credits-summaries-scoring-qa`

---

## Rules Added

Five rules added to `~/claude-hub/inflow-ats/CLAUDE.md` under "Known Failure Patterns" (4 from Rounds 1-4, 1 from Rounds 5-6):

### Rule 6: Rename cascades -- grep for ALL references, including spec files

When renaming an identifier, grep the entire codebase for every reference to the old name. Do not rely on the plan's file list. When fixing a stale reference found by review, grep again to confirm zero remaining references.

**Motivated by:** impl-round-1 H3 + impl-round-2 H1. The plan listed 9 app files for the settings key rename but omitted 3 spec files. The fix agent for Round 1 updated only the 2 files named in the failure report without grepping for others, causing the same defect class to recur in Round 2.

### Rule 7: Test stubs must not mask type mismatches at API boundaries

Stubs must match what production code actually passes. If production passes an invoice ID where a checkout session ID is expected, the stub should not silently accept it.

**Motivated by:** impl-round-1 H1. The `invoice.paid` handler passed a Stripe invoice to `ApplyAiCreditPurchase`, which called `Stripe::Checkout::Session.list_line_items` with an invoice ID. The spec stubbed `list_line_items` to accept the invoice ID, masking a `Stripe::InvalidRequestError` that would fire in production.

### Rule 8: Webhook handlers -- trace guard ordering before adding new branches

Before adding a new branch to a webhook handler, trace the full control flow from entry to the new branch. Verify no intervening guard rejects the new branch's use case.

**Motivated by:** spec-round-1 BLOCKER + plan-review pass-1 HIGH. The `invoice.paid` handler's `CustomStripeSubscriptionMissingError` guard blocked the new `ai_credit_pack_top_up` branch for orgs without a subscription. The plan also incorrectly claimed listing branches "already `return`" when they did not, risking fall-through to the guard.

### Rule 9: Multi-step payment flows -- validate fields only when they become known

Make validations conditional on lifecycle state when a record is created early but some fields are populated later.

**Motivated by:** spec-round-1 HIGH + spec-round-2 HIGH. `OrganizationAiCreditPurchase` had unconditional validations on `amount_cents_paid` and `currency`, but the two-step subscription handshake creates the purchase at checkout before payment.

### Rule 10: Fix agents must not add code beyond the defect scope

When fixing a defect found by review, the fix must be the minimum change that resolves the specific finding. Do not rewrite methods from scratch, add new event handlers, or introduce new migrations that were not in the spec. If the fix seems to require substantial new functionality, stop and flag it for a new spec/plan/review cycle.

**Motivated by:** impl-round-5 (9 HIGH findings). A fix agent given a single defect (invoice passed where checkout session expected) wrote ~200 lines of new code: `apply_one_off_from_invoice` (46 lines), 3 new webhook handlers, a complete `handle_credit_pack_invoice_paid` rewrite (59 lines), `subscription_status_for_stripe` helper, validation relaxation, and a new migration. All removed in Round 6.

---

## Existing Rules Violated

### Rule 5 violated: "Full-stack feature specs must list all modified files, not just new files"

The plan's "Files to Modify" table for the enum rename listed 9 app files but omitted 3 spec files that referenced the old identifiers. This is the exact scenario Rule 5 was designed to prevent. The implementing agent followed the plan faithfully, so the omitted spec files were never updated.

**Where it failed:** Plan step Note #5 (enum rename cascade). The plan listed all model/controller/frontend files but did not include `job_ai_settings_spec.rb`, `textract_result_ai_trigger_spec.rb`, or `organization_ai_credits_lifecycle_spec.rb`.

**Why Rule 5 didn't prevent it:** Rule 5 targets the spec document ("specs must list all modified files"). The spec itself was reviewed and passed. The gap was in the plan, which translated the spec's requirements into a file list but did not grep for additional ripple sites in `spec/`. New Rule 6 closes this gap by requiring a grep at implementation time regardless of what the plan lists.

---

## Findings Skipped (not added as rules)

### impl-round-1 H2: `AccountPlatoAiContainer` missing `currentOrganization` prop

A React container wrapper was introduced but did not thread `currentOrganization` (obtained from `useCurrentSession()`) to its child. This caused a runtime crash on `undefined.settings`.

**Why skipped:** This is a general React prop-threading mistake during component extraction, not a recurring inflow-ats-specific pattern. The existing global CLAUDE.md rule about tracing entire pipelines end-to-end covers this class of error. It would also be difficult to write a concise, actionable rule beyond "when extracting a component into a wrapper, make sure all props still arrive."

### spec-round-1 MED: Dead code after branch removal

`apply_top_up_checkout` became dead code when its sole caller was removed. The spec did not mention removing it.

**Why skipped:** One-off cleanup omission. Not a recurring pattern.

### spec-round-1 MED: TypeScript type name not renamed alongside enum values

`AutoGenerateAiSummariesSetting` should have been renamed to `AutoGenerateAiSummaries` when the enum values were renamed.

**Why skipped:** Covered by new Rule 6 (grep for all references to old names).

### plan-review MED: "Files to Create" table lists existing file as new

The plan listed `bulk_generate_ai_summaries_job_spec.rb` as a new file, but it already existed. The plan's prose instructions correctly said "add two new describe blocks."

**Why skipped:** Cosmetic inconsistency in the plan document. The prose was correct and the implementing agent followed the prose.

### impl-round-1 MEDs: Stale comment, subscription_status timing, mailer name field, update_columns without comment

All minor code quality issues. None represent recurring patterns.

### impl-round-2 MEDs: Dead `apply_subscription` method, silent return in `handle_credit_pack_invoice_paid`

Cleanup and observability issues flagged for awareness. Not recurring patterns.

### impl-round-5 HIGH findings 2-9: Individual out-of-spec additions

The 9 HIGH findings from Round 5 all share a single root cause (fix agent scope creep). They do not represent 9 separate failure patterns -- they are 9 manifestations of one pattern (Rule 10). The individual items (validation relaxation, 3 webhook handlers, method rewrite, duplicate method, helper method, code duplication) are not separately actionable rules because preventing the root cause prevents all of them.

### impl-round-5 MEDs: `amount_cents_paid: 0`, rescue restructuring, `self.class.send`, feature flipper, missing `exact={false}`

Carried forward from Round 5 to Round 6 as non-blocking. The `amount_cents_paid: 0` is harmless (overwritten on first `invoice.paid`). The rescue restructuring and feature flipper are reasonable deviations. The `exact={false}` and `self.class.send` are style items.

---

## Summary Statistics

| Phase | Rounds to Pass | BLOCKERs | HIGHs | Rules Extracted |
|-------|---------------|----------|-------|-----------------|
| Spec  | 4 (2 fail + 2 pass) | 1 | 3 | 2 (Rules 8, 9) |
| Plan  | 2 (1 fail + 1 pass) | 0 | 1 | 0 (covered by Rule 8) |
| Impl (rounds 1-4) | 4 (2 fail + 2 pass) | 0 | 5 | 2 (Rules 6, 7) |
| Impl (rounds 5-6) | 2 (1 fail + 1 pass) | 0 | 9 | 1 (Rule 10) |
| **Total** | **12** | **1** | **18** | **5** |

Existing rules violated: 1 (Rule 5).
Findings skipped: 9 (one-offs or covered by new/existing rules).

### Round 5-6 root cause

All 9 Round 5 HIGH findings trace to a single root cause: a fix agent dispatched to resolve a type mismatch (impl-round-1 H1: invoice passed where checkout session expected) instead wrote ~200 lines of entirely new functionality. The fix agent:
- Created `apply_one_off_from_invoice` (46 lines) duplicating existing `apply_one_off`
- Added `charge.refunded`, `customer.subscription.updated`, and `customer.subscription.deleted` handlers (66 lines total)
- Rewrote `handle_credit_pack_invoice_paid` from scratch (59 lines instead of 13)
- Added `subscription_status_for_stripe` helper (11 lines)
- Relaxed `stripe_checkout_session_id` validation for one-offs (out of spec)
- Created migration `20260605035312` (not needed)

Round 6 verified all out-of-spec code was removed and the spec-compliant implementation remained intact. Seven non-blocking MED findings were noted for optional follow-up.
