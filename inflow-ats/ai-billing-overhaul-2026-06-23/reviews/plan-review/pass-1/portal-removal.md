# Angle 6: Portal Flow Removal — Pass 1 Findings

## Verified claims

### Controller action boundaries
- `change_subscription_portal_session`: actual lines 233-281. Plan says "lines 229-281" in A.4.1 — the comment block starts at 228, method `def` at 233. The REVIEW-ANGLES.md correctly says "lines 233-281." Plan step A.4.1 says "lines 229-281" which includes the comment. Not a functional error, but the plan is inconsistent with itself (A.2.2 says "around line 233" which is correct).
- `update_payment_method_and_subscription_portal_session`: actual lines 286-338. Plan says "lines 284-338" in A.4.2 — comments start at 283, `def` at 286. Same pattern: plan includes the comment block.
- `continue_change_subscription_portal_session`: actual lines 345-415. Plan says "lines 342-415" in A.4.3 — comments start at 340, `def` at 345. Same pattern.

### Routes
Verified at lines 190-201 of `config/routes.rb`:
- Line 195: `post :change_subscription_portal_session` ✓
- Line 196: `post :update_payment_method_and_subscription_portal_session` ✓
- Line 200: `get :continue_change_subscription_portal_session` ✓
All correct.

### Spec file
File exists at `spec/controllers/api/v1/organization_ai_credit_purchases_change_subscription_spec.rb`. Plan claims 154 lines; actual count is **193 lines**.

### Grep results — no orphaned references outside expected files
All references to portal identifiers are in exactly the files the plan accounts for:
- Controller: `organization_ai_credit_purchases_controller.rb` (being modified)
- Routes: `config/routes.rb` (being modified)
- Frontend hooks: `useOrganizationAiCreditPurchase.ts` (being modified)
- Frontend component: `AiCreditSubscription.tsx` (being modified)
- Spec: `organization_ai_credit_purchases_change_subscription_spec.rb` (being removed)
- Billing controller + routes: `billing_controller.rb` lines 168-178 (NOT removed — ATS plan, not AI credits) ✓
- useBilling.ts: lines 56, 71 (NOT removed — ATS plan) ✓

No unexpected orphaned references found.

### Billing controller owns its own portal methods ✓
- Line 268: `def change_subscription_portal_session` ✓
- Line 331: `def update_payment_method_and_subscription_portal_session` ✓
- Line 385: `def continue_change_subscription_portal_session` ✓

### `useBilling.ts` portal functions ✓
- Line 56: `path: \`/billing/change_subscription_portal_session\`` ✓
- Line 71: `path: \`/billing/update_payment_method_and_subscription_portal_session\`` ✓

### `redirectToStripe` usage ✓
- Defined at line 75 of `AiCreditSubscription.tsx`
- Called at line 231 inside `purchaseTopUpCheckoutSession` (the top-up checkout flow)
- Plan correctly says to KEEP this function ✓

## Findings

### MED-1: Spec file line count mismatch
Plan step C.1.1 says the spec file is "154 lines." Actual: **193 lines.** This is a minor factual error — the file still gets removed entirely, so the line count doesn't affect the implementation. But the plan should be accurate.

### LOW-1: Controller removal line numbers include comment blocks
Plan steps A.4.1-A.4.3 reference line numbers that include the comment blocks above each method (e.g., "lines 229-281" when the `def` is at 233). This is directionally correct — the comments should be removed too — but inconsistent with other plan references (A.2.2 says "around line 233" for the same method). Not a functional issue; the implementation agent will remove the entire block regardless.

## Verdict

0 BLOCKER, 0 HIGH. The portal removal coverage is complete — all references are accounted for, no orphaned code will remain. The spec file line count is wrong but inconsequential.
