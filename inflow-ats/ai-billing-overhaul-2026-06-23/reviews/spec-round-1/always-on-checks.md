# Always-On Checks — Round 1

## 1. Variable naming — PASS with note
The spec uses `organization_ai_credit_purchase` throughout the backend code (never `purchase` standalone). Uses `balance` as shorthand matching the existing `ApplyAiCreditPurchase` pattern. `ai_credit_balance_transaction` is used for the transaction record. PASS.

Note: The spec correctly identifies (line 315) that `CancelAiCreditSubscription` uses `purchase` as a naming violation and says the new interactor must NOT copy this.

## 2. No begin blocks in controllers — PASS
Spec says "method-level rescue" for both new actions (lines 101, 140). Matches core critical rule 1. PASS.

## 3. Single quotes in Ruby — PASS
Spec uses single quotes in all Ruby code examples (e.g., `'subscription_update'` at line 238, `'subscription_cycle'` at line 243). Interpolated strings use double quotes (e.g., line 305). PASS.

## 4. No bang methods — PASS
The spec's `ApplyAiCreditUpgrade` code uses `save` (not `save!`), `update` (not `update!`). PASS.

## 5. Check save/update return values — PASS
All `save` and `update` calls have their return values checked with `unless activated` / `unless ai_credit_balance_transaction.save` / `unless updated` patterns. PASS.

## 6. No fabricated fallback values — PASS with note
The spec uses `|| ""` for `paymentMethodLabel` (line 587) and `currentPlanNameFromPreview` (line 583). These are display strings for modal props where empty string is the appropriate "no data" representation in a UI text context. The `|| ""` for `useState` initializers is explicitly allowed. For display-only strings where the fallback is "show nothing", empty string is acceptable per rule 10's note about `useState` initializers. These are not database-backed record IDs or values where nil has semantic meaning. LOW risk, PASS.

## 7. Never deliberately set undefined — PASS
No explicit `undefined` assignments in the spec's TypeScript code. PASS.

## 8. Theme colors verified — N/A
The spec does not specify any color values directly. The modal uses emotion styled components but defers colors to the handoff file (visual reference). Verification will happen at implementation review. N/A.

## 9. Emotion theme utilities — N/A
No specific theme utility usage in the spec code. N/A.

## 10. Styled components: separate visual variants — PASS
The spec describes upgrade and downgrade as conditional rendering within a single modal component (using the `isDowngrade` prop to show/hide sections), not as a styled component conditional prop. This is correct — `isDowngrade` controls content layout, not CSS styling. PASS.

## 11. Backend snake_case, frontend camelCase — PASS
Backend uses `preview_subscription_change`, `commit_subscription_change` (snake_case). Frontend uses `previewSubscriptionChange`, `commitSubscriptionChange` (camelCase). API layer transforms automatically. Preview response uses `camelCase` keys (`amountDue`, `lookupKey`, `currentPeriodEnd`). PASS.

## 12. No `hasUnsavedChanges` on the modal — PASS
Spec constraint C6 explicitly states `hasUnsavedChanges` should be omitted. PASS.

## 13. Handoff file is visual reference only — PASS
Spec constraint C5 explicitly states all identifiers come from the codebase. The spec's code uses codebase imports (`CenterModal`, `Button`, etc.) and codebase constants (`AI_CREDIT_PACK_DISPLAY_NAMES`, etc.). PASS.

## 14. Test requirements covered — PASS
The spec has a complete "Test requirements" section (lines 829-863) covering:
- Controller specs for both new actions (success, no subscription, non-admin, Stripe error)
- Interactor specs for both new interactors
- Webhook handler spec for `billing_reason` routing
- Existing spec removal for deleted actions
This satisfies known failure pattern #3. PASS.

## 15. Guard clause bare returns — PASS
The spec's guard clauses use bare `return` (e.g., `return if organization_ai_credit_purchase.stripe_invoice_id == invoice.id` at line 283, `return context.fail!(...)` at line 279). The `context.fail!` returns are acceptable — they're not returning truthy/falsy values, they're failing the interactor context. PASS.

## Verdict

0 findings from always-on checks.
