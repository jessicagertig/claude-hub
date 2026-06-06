# angle-2: controller-restructuring-and-route-alignment — Pass 1

## Fact Check

| Claim | Verification | Result |
|-------|-------------|--------|
| `AiCreditsController` exists at stated path | ls confirmed | CORRECT |
| `AiCreditSubscriptionsController` exists at stated path | ls confirmed | CORRECT |
| `AiCreditPolicy` exists at stated path | ls confirmed | CORRECT |
| `AiCreditSubscriptionPolicy` exists at stated path | ls confirmed | CORRECT |
| Current routes: `resource :ai_credits` at line 189 | Read routes.rb lines 188-200 | CORRECT |
| Current routes: `resource :ai_credit_subscriptions` at line 195 | Read routes.rb lines 195-200 | CORRECT |
| `AiCreditsController#show` uses `render_one` with `OrganizationAiCreditBalanceSerializer` | Read controller lines 9-10 | CORRECT |
| `AiCreditsController#show` authorizes `:ai_credit, :show?` | Read controller line 7 | CORRECT |
| `AiCreditSubscriptionsController#show` wraps response in `{ ai_credit_subscription: ... }` | Read controller lines 10-12 | CORRECT |
| `AiCreditSubscriptionsController#subscribe` authorizes via `BillingPolicy#create_subscription?` | Read controller line 17 | CORRECT |
| `AiCreditSubscriptionsController#cancel` authorizes via `BillingPolicy#cancel_subscription?` | Read controller line 54 | CORRECT — `authorize :billing, :cancel_subscription?` |
| Plan D.3 `purchase_top_up` authorizes via `BillingPolicy#checkout?` | Existing `AiCreditsController#purchase_top_up` line 14 uses `:billing, :checkout?` | CORRECT — matches |
| Plan D.4 routes use `resource` (singular) | Current routes use `resource` (singular) | CORRECT |
| `AiCreditPacks` references in controllers will be removed when controllers are deleted | Both old controllers reference `AiCreditPacks` | CORRECT — deletion handles this |
| New controller params key `:organization_ai_credit_purchase` | Plan D.3 states this | Consistent with spec |

## Completeness

Spec requirements covered by this angle:
- Note #9A controller creation — plan steps D.2, D.3
- Note #9A controller deletion — plan step D.5
- Note #9A policy renames — plan step D.1
- Note #9A route replacement — plan step D.4
- `render_one` for show (no envelope) — plan steps D.2, D.3

All spec requirements have corresponding plan steps.

## Findings

No issues found.

## Amendments Applied

(none)
