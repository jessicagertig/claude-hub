# Angle 1: Stripe API Contract — Round 2

## Re-verification of Round 1 amendment (S1)

The `newMonthlyPrice` prop now uses `tier.priceDollars` instead of the invoice line item amount. `priceDollars` is typed as `number` (e.g., `129`), not a formatted string. The existing codebase uses it as `${tier.priceDollars}` (integer with $ prefix, no decimal). The modal prop `newMonthlyPrice` is typed as `string` (e.g., `"$129.00"`).

The implementer will need to format `tier.priceDollars` to match the expected string format. This is a routine formatting task — the spec's `formatCents` helper already shows the pattern. LOW severity — no spec amendment needed, implementer will handle the formatting.

## New check: `isDowngrade` param vs server-side computation

### S3: `commit_subscription_change` — inconsistency between server-side upgrade/downgrade determination and frontend `isDowngrade` param — MED

**Location:** SPEC.md lines 114 and 508-510

**Problem:** The spec contains two contradictory statements about how the controller determines upgrade vs. downgrade:

1. Line 114: "Determine if this is an upgrade or downgrade based on the lookup keys (compare `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` credit amounts)" — this is server-side computation.

2. Lines 508-510: The `CommitSubscriptionChangeParams` interface includes `isDowngrade: boolean`, and the frontend sends `{ priceId: tier.priceId, isDowngrade }` (line 602). This implies the backend reads the frontend's `isDowngrade` param.

If the backend computes upgrade/downgrade server-side from lookup keys, the frontend's `isDowngrade` param is dead code — `CommitSubscriptionChangeParams` should not include it, and the frontend should not send it.

If the backend trusts the frontend's `isDowngrade` param, a malicious client could send `isDowngrade: false` for an actual downgrade, causing an immediate `Stripe::Subscription.update` with proration charges instead of scheduling it at period end. This is a security concern (albeit a minor one — the user is still charged, just in a different way).

**Recommended fix:** The backend should compute upgrade/downgrade server-side (as line 114 states). Remove `isDowngrade` from `CommitSubscriptionChangeParams` and from the `commitSubscriptionChange` mutation call. The controller should determine this by comparing `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY[current_lookup_key]` vs `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY[new_lookup_key]`.

## Verdict

1 MED finding (S3). Requires spec amendment.
