# QA MED Findings -- AI Summaries Phase 1 Changes

Consolidated MED findings across all layers and all runs (1-4). These are real observations that do NOT require fixing during QA -- they require design decisions, are spec-compliant, or are non-blocking deviations.

---

## RESOLVED Findings

### M1. CREDIT_PACKS_BY_LOOKUP_KEY missing `name` field from spec -- RESOLVED
Resolved in qa-run-4 by F-003. All four pack hashes now include `name:` keys matching the spec.

### M4. AI_TASKS_README.md missing 2 of 5 on-demand tasks -- RESOLVED
Resolved in qa-run-4 by F-005/F-006. Both `ai:relevance_benchmark` and `ai:comparison_benchmark` now documented.

### M5. `stripe_checkout_session_id` validation relaxation beyond spec scope -- RESOLVED
Resolved in qa-run-3 cleanup.

### M6. invoice.paid top-up handler uses checkout session lookup instead of invoice metadata -- RESOLVED
Resolved in qa-run-4 by F-001. Handler now reads `organization_id` and `stripe_price_lookup_key` from invoice metadata directly.

### M8. No charge.refunded handler for credit packs -- RESOLVED
Resolved in qa-run-4 by F-002. `handle_charge_refunded` restored per approved decision Note #33.

---

## Active Findings

### M2. Checkout action sets `amount_cents_paid: 0` instead of nil

**Source:** Layer 1, qa-run-1 round 1
**Confirmed across:** All 4 runs

The spec relaxes validations so `amount_cents_paid` is not required for pre-checkout subscription records. The implementation sets `amount_cents_paid: 0` explicitly rather than leaving it nil.

**Impact:** Semantically misleading (0 implies "free" rather than "unknown"), but functionally harmless. Overwritten with the real amount when `invoice.paid` fires.

---

### M3. Plato AI container passes `currentOrganization` prop to all children

**Source:** Layer 1, qa-run-1 round 1
**Confirmed across:** All 4 runs

`AccountPlatoAiContainer` passes `currentOrganization={currentOrganization}` to child components. Extra props are harmless in React.

---

### M7. handle_credit_pack_invoice_paid does not update subscription period dates or status

**Source:** Layer 1, qa-run-3 round 1

The handler updates only `amount_cents_paid` and `currency`, then delegates to `ApplyAiCreditPurchase`. Subscription period dates and status remain nil after the first `invoice.paid`. The `customer.subscription.updated` handler that would have populated these was removed as out-of-spec code.

**Impact:** Subscription management UI would need period dates, but that is outside Phase 1 scope. Manual inspection is available via `rails console`.
