# angle-3: hook-consolidation-and-response-shape-change — Round 1

No BLOCKER or HIGH findings. Verified:

- `useAiCreditSubscription.ts`, `useSubscribeToAiCreditPack.ts`, `usePurchaseAiCreditTopUp.ts`, `useCancelAiCreditSubscription.ts` all exist and are correctly listed for deletion.
- `useOrganizationAiCreditBalance.ts` exists and is correctly left standalone.
- The current `ai_credit_subscriptions_controller.rb#show` wraps the response in `{ ai_credit_subscription: ... }` (line 10-12). The spec correctly notes the response shape change to unwrapped.
- The `planHelpers.ts` code uses `p.lookupKey` (camelCase), consistent with the API layer's automatic snake_case → camelCase transform (core critical rule #7).
- Query key rename from `["aiCreditSubscription"]` to `["organizationAiCreditPurchase"]` is noted.
- Params key change from `{ aiCreditSubscription: ... }` to `{ organizationAiCreditPurchase: ... }` is noted.

All findings clear for this angle.
