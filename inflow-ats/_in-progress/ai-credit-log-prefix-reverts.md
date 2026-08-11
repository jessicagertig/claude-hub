# AI Credit — window.logger prefix reverts (DONE)

STATUS: reverted. All `window.logger` prefixes and trailing hook tokens in `AiCreditSubscription.tsx` and `useOrganizationAiCreditPurchase.ts` were changed back to our own names (`[AiCreditSubscription]`, `[useOrganizationAiCreditPurchase]`, our hook names). Verified no `[AccountBilling]`/`[useBilling]` remain. The table below is the historical record.



During the analog-match loop we are deliberately matching `window.logger` prefixes to the analog's literal tokens so the audit stays maximally close to the analog and real divergences don't hide behind an allowlist. These are WRONG for our components long-term (they name the billing analog, not our credit feature) and must be reverted once the flow is otherwise clean.

Revert these AFTER the loop converges:

| File | Currently being set to (analog literal, TEMP) | Revert to (correct for our feature) |
|---|---|---|
| `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx` | `[AccountBilling]` | `[AiCreditSubscription]` |
| `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` | `[useBilling]` | `[useOrganizationAiCreditPurchase]` |

Also the trailing hook-name tokens inside the log strings (e.g. `useChangePlanStripePortalSession`, `useUpdateWithPaymentMethod`, `useStripeCustomerSubscription`) are the analog's literals; if matched, revert them to our hook names later.

Note: the analog's own log tokens are internally inconsistent (some don't match their hook name), so "match the analog literally" here is purely a temporary audit-cleanliness measure, not a final state.

## Error message to revisit

`change_subscription_portal_session` and `update_payment_method_and_subscription_portal_session`: the subscription-presence guard was collapsed to ONE guard matching the analog — `raise StandardError, 'No active credit subscription found.' if purchase.nil? || purchase.stripe_subscription_id.blank?`. We previously had a distinct second guard, "Subscription is not yet active in Stripe. Please try again shortly.", for the intermediate webhook-pending state (purchase row exists but `stripe_subscription_id` not yet set). Structure now matches the analog; revisit the error-message WORDING later (we may want to restore a retry hint for the webhook-pending state). Everything else stays matched.

