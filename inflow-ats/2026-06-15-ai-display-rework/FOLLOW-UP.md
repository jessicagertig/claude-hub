# Follow-up Work — After Rework Passes

## Time constraint

Keep working until 10am CDT 2026-06-16 (Unix timestamp: 1750172400). Check `date +%s` against this before considering stopping.

## AI Settings Redesign — DONE

1. ✅ Stash applied
2. ✅ Audit complete — 3 violations found and fixed:
   - AiCreditMeter dark mode tones (subscription fill invisible on dark track)
   - AiCreditSubscription passing `undefined` → changed to `null`
   - AiSubscriptionTierCard PromoBadge — intentional (gradient is always light)
3. ✅ No billing display conflict — `aiCreditPrices()` only returns prices that exist in Stripe; stubbed tiers silently drop out
4. ✅ Playwright screenshots taken — all 3 AI settings pages + Plan & billing render correctly
5. ✅ Committed (pending Cypress hook)

## Base branch context

- Stash was created on `ai-display-rework` (branched from `ai-frontend-work`)
- Stashed files: `accountAdmin/OrganizationAiBilling.tsx`, `OrganizationAiSettings.tsx`, `OrganizationAiUsage.tsx`, `accountPlatoAi/AccountPlatoAiContainer.tsx`, `accountPlatoAi/AiCredit*.tsx`, `accountPlatoAi/AiSubscription*.tsx`, `accountPlatoAi/aiSubscriptionHelpers.ts`, `shared/lib/planHelpers.ts`
- The `planHelpers.ts` change (third tier/top-up stubs + display name map) is the likely cause of the billing display issue
