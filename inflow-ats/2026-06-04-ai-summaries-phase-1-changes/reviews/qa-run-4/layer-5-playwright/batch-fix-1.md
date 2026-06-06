# Batch Fix 1 -- Layer 5 Round 1

## Finding H1: Stale "go to AI billing" link

**File:** `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBilling.tsx`
**Line:** ~143 (in the feature diff)
**Current:** `<Link to="/hire/settings/ai-billing">go to AI billing</Link>`
**Should be:** `<Link to="/hire/settings/plato-ai/billing">go to AI billing</Link>`

The feature added this link pointing to a route that was removed by the same feature.
