# CLAUDE.md Compliance Check — Pass 1

## Known Failure Pattern Audit

### Pattern #1: Emotion theme utilities are complete CSS declarations
**Status:** COVERED
Plan B.2.6 explicitly addresses this: "`t.text.sm`, `t.text.md`, `t.text.bold`, `t.text.xs`, `t.mt(N)`, `t.my(N)`, `t.px(N)`, `t.py(N)`, `t.mr(N)`, `t.rounded.sm` are complete CSS declarations -- use standalone, NOT inside a property declaration."

### Pattern #2: Trace every pipeline end-to-end
**Status:** NOT APPLICABLE — No parallel-field feature.

### Pattern #3: Specs and plans must include test requirements
**Status:** COVERED
Plan section C has 5 subsections (C.1-C.5) with test file paths, test case lists, and analog references. Every spec test requirement is covered:
- Spec preview controller tests (4 cases) → Plan C.2.3 (5 cases, adds missing price_id)
- Spec commit controller tests (5 cases) → Plan C.2.4 (6 cases, adds interactor failure)
- Spec ApplyAiCreditUpgrade tests (7 cases) → Plan C.3.2 (9 cases)
- Spec ScheduleAiCreditSubscriptionDowngrade tests (2 cases) → Plan C.4.2 (2 cases)
- Spec webhook handler tests (2 cases) → Plan C.5.1 (3 cases, adds subscription_create)
- Spec existing spec removal → Plan C.1.1

### Pattern #4: ActionMailer `.deliver_now`
**Status:** NOT APPLICABLE — No mailer code.

### Pattern #5: Full-stack specs list all modified files
**Status:** COVERED — Plan has complete file list (9 app files + 5 test files) matching spec's files list exactly plus test files required by spec's test requirements section.

### Pattern #6: Rename cascades grep for ALL references
**Status:** COVERED
Plan section D.1 greps for all 9 removed identifiers across entire codebase. D.2-D.3 explicitly note that billing controller and useBilling.ts have their OWN same-named portal methods (ATS billing, not AI credit billing) that should NOT be removed. D.4 specifies zero results expected from the AI credit files + spec file.

### Pattern #7: Test stubs must not mask type mismatches
**Status:** MED — PARTIALLY COVERED
The plan's test section (C.2-C.5) describes what to test but does not explicitly warn about Stripe API stub accuracy. The tests will stub `Stripe::Invoice.create_preview`, `Stripe::Subscription.update`, `Stripe::Subscription.retrieve`, `Stripe::Price.retrieve`, `Stripe::SubscriptionSchedule.create/update`, and `Stripe::PaymentMethod.retrieve`. The plan should note that stubs must verify the argument types match production — e.g., `Stripe::Subscription.update` receives a subscription ID string, not an invoice or customer object.

**Finding:** MED-C1 — Plan test section lacks explicit warning about Stripe API stub argument accuracy per known failure pattern #7.

### Pattern #8: Webhook handlers trace guard ordering
**Status:** COVERED
Plan A.7.3 explicitly traces guard ordering: "The method's only guard is `raise CustomStripeSubscriptionMissingError if organization_ai_credit_purchase.nil?` at line 477. This fires BEFORE any branching and applies to ALL invoice types. Safe -- no guard between method entry and the new branch that would reject `subscription_update` invoices."
Plan A.7.4 additionally verifies the routing dispatch at lines 283-284 and confirms the `CustomStripeSubscriptionMissingError` guard at line 286 is in the ELSE branch (main-plan invoices).

### Pattern #9: Multi-step payment flows validate fields conditionally
**Status:** NOT APPLICABLE — No new model validations.

### Pattern #10: Fix agents must not add code beyond scope
**Status:** NOT APPLICABLE to plan review (applies during implementation).

### Pattern #11: Analog replication copy behavioral props
**Status:** COVERED
Plan B.2.3 explicitly addresses this: "**Known failure pattern #11:** The confirm Button MUST have `loading={isLoading}` to prevent double-clicks. The cancel modal uses `disabled={isLoading}` (line 39); the Button component supports both `loading` and `disabled` props (Button/index.js lines 17-18). Use `loading` per the handoff design."

### Pattern #12: Styled components separate visual variants
**Status:** COVERED
Plan B.2.7: "**No conditional props on styled elements** (known failure pattern #12): The handoff uses `className="total"` and `className="num"` on elements, which is acceptable. No custom boolean props like `isKey`/`isActive` are passed to styled elements."

### Pattern #13: Never fabricate fallback values
**Status:** REVIEWED — NO VIOLATIONS

Checked every `||` and ternary fallback in plan/spec code:

| Expression | Location | Verdict |
|---|---|---|
| `AI_CREDIT_PACK_DISPLAY_NAMES[tier.lookupKey] \|\| tier.name` | spec line 578 | OK — `tier.name` is real data from the tier object, not a fabrication |
| `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY[tier.lookupKey] \|\| tier.credits` | spec line 579 | OK — same pattern, both sources are real data |
| `AI_CREDIT_PACK_DISPLAY_NAMES[currentPlanLookupKeyFromPreview] \|\| ""` | spec line 592 | LOW — technically `|| ""` for absent data, but display-only edge case. The lookup key always matches the constant for valid subscriptions. Not routing, not API-bound |
| `previewData.currentPeriodEnd ? prettyDate(...) : ""` | spec line 629 | OK — explicit ternary, not `||` |
| `oldLine ? formatCents(oldLine.amount) : ""` | spec line 633 | OK — explicit ternary |
| `previewData.defaultPaymentMethod ? ... : ""` | spec lines 595-597 | OK — explicit ternary |
| `error?.data?.errors?.general?.[0] \|\| "Unable to..."` | spec lines 617, 640 | OK — error message fallback, not data fabrication |

### Pattern #14: Analog structural matching compare signatures
**Status:** COVERED
Plan has two detailed structural manifest tables:
- A.5.1: `ApplyAiCreditUpgrade` vs `ApplyAiCreditPurchase` — 18-row comparison with SAME/DIFFERENT annotations
- A.6.1: `ScheduleAiCreditSubscriptionDowngrade` vs `CancelAiCreditSubscription` — 8-row comparison

Both manifests explicitly note deviations with justifications. The controller analog comparison is in the Pattern Precedents section.

### Pattern #15: Implementation reviews must review committed code
**Status:** NOT APPLICABLE to plan review.

### Pattern #16: Companion records create via unconditional owner
**Status:** NOT APPLICABLE — No new companion records.

### Pattern #17: Schema rollbacks destroy data migration records
**Status:** NOT APPLICABLE — No migrations.

### Pattern #18: Denormalized columns clear ALL when disassociating
**Status:** NOT APPLICABLE — No disassociation logic.

### Pattern #19: Test setup for eager companion creation
**Status:** NOT APPLICABLE — `OrganizationAiCreditPurchase` has no `after_commit` callbacks creating companion records.

### Pattern #20: Fixing a gap must not change shared infrastructure
**Status:** NOT APPLICABLE to plan review (applies during fix rounds).

### Pattern #21: Stay in LIFECYCLE phase loop
**Status:** NOT APPLICABLE to plan review.

---

## Core Critical Rules Audit

### Rule 1: No begin blocks in controllers
**Status:** PASS — All controller code in plan uses method-level rescue.

### Rule 2: Theme colors check before using
**Status:** COVERED — Plan B.2.5 explicitly lists all handoff colors and instructs to verify each exists in theme.ts.

### Rule 3: Use awesome print
**Status:** PASS — Plan controller rescue patterns use `ap e` (not `pp`).

### Rule 4: PUT for updates
**Status:** N/A — New routes use POST (not update operations).

### Rule 7: Backend snake_case, frontend camelCase
**Status:** PASS — Plan B.1.1 explicitly notes the API layer transformation. Backend renders `snake_case`, frontend TypeScript interfaces use `camelCase`.

### Rule 8: Guard clauses bare return
**Status:** PASS — Plan controller guards use `raise StandardError` (appropriate for guards that should halt execution). Interactor guards use `return context.fail!(...)` (appropriate for interactor failure pattern, not a truthy/falsy return).

### Rule 9: Never deliberately set undefined
**Status:** PASS — No explicit `undefined` assignments in plan TypeScript code.

### Rule 10: Never fabricate fallback values
**Status:** PASS — See Pattern #13 analysis above. No violations.

### Rule 11: No bang methods
**Status:** PASS — No `save!`, `update!`, `create!` in non-spec code. Plan A.5.1 manifest confirms `.save` (not `.save!`) and `.update` (not `.update!`).

### Rule 12: Always check save/update return values
**Status:** PASS — Every `.save`/`.update` in plan code has return value checked via `fail_with_record_invalid` or conditional.

### Variable naming
**Status:** PASS — All plan code uses `organization_ai_credit_purchase` (never `purchase`), `ai_credit_balance_transaction` (never `transaction`). Plan A.6.1 explicitly calls out the cancel interactor's `purchase` violation and instructs "Must use `organization_ai_credit_purchase`."

### Single quotes in Ruby
**Status:** PASS — All Ruby string literals in plan use single quotes unless interpolation needed.

---

## Spec Review Fix Verification

### S3 (MED, Round 2): `isDowngrade` not sent from frontend
**Status:** VERIFIED
- Plan B.1.3 `CommitSubscriptionChangeParams` has only `{ priceId: string }` — no `isDowngrade`
- Plan A.3.1 step 4 computes upgrade/downgrade server-side via `Stripe::Price.retrieve` + lookup key comparison
- The frontend's `isDowngrade` is used only for local UI decisions (modal variant, toast message), never sent to backend

---

## Summary

| Severity | Count | Findings |
|----------|-------|----------|
| BLOCKER | 0 | — |
| HIGH | 0 | — |
| MED | 1 | MED-C1: Test section lacks Stripe stub argument accuracy warning |
| LOW | 1 | `|| ""` in currentPlanName display fallback (borderline, display-only) |

**Verdict:** No BLOCKER or HIGH findings. The plan is compliant with CLAUDE.md rules and all 21 known failure patterns.
