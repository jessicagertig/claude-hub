# Round 4 — Fix Log (subscription-change analog trace)

All 8 findings verified against the analog code in
`/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza` and corrected in
`traces/subscription-change-analog-trace.md`. Analog-only; no "ours" content added.

## D1 — `isLoading` prop never traced to its source (item 16)
Verified `AccountBillingPlans.tsx:450-452` passes
`isLoading={isLoadingChangeSubscriptionViaStripePortal || isLoadingUpdateWithPaymentMethod}`,
the two booleans destructured from `useChangeSubscriptionViaStripePortal` (`:123-126`)
and `useUpdateWithPaymentMethod` (`:130-133`). Item 16 now traces the prop to both
react-query mutation-hook terminals and documents `disabled={isLoading}` (`PlanCard.tsx:210`)
as carrying it.

## D2 — `isLoadingButton`/`isFetchingStripeCustomerSubscription` second SCREEN terminal (items 9 + 16)
Verified `isLoadingButton={isFetchingStripeCustomerSubscription}` at
`AccountBillingPlans.tsx:453` → `loading={isLoadingButton}` at `PlanCard.tsx:209`.
Item 9 rewritten to list TWO SCREEN consumers of the flag (early-return LoadingIndicator
`:352-354` AND the PlanCard button); item 16 documents the `:453` source.

## D3 — missing `ap :333` in `update_payment_method_and_subscription_portal_session` (item 18b)
Verified `ap 'Update Payment Method then redirect to Confirm Subscription Change via Stripe Portal'`
at `billing_controller.rb:333` (2nd executable statement, between authorize `:332` and guards
`:335-337`). Added to item 18b.

## D4 — missing `ap :386` in `continue_change_subscription_portal_session` (item 18b)
Verified `ap 'Continue: Create Subscription Confirmation Portal Session after Payment Method Update'`
at `billing_controller.rb:386` (FIRST executable statement, before the customer-blank guard `:390`).
Added to item 18b.

## D5 — ValidateSubscriptionChange control structure: no `else` (item 24)
Verified the `if current_published_count > target_job_limit` block (`:53-73`) contains only
`context.fail!` (`:72`); `context.success!` (`:76`) runs UNCONDITIONALLY after the `if`,
reached on the within-limit path because `context.fail!` halts via `Interactor::Failure` raise.
Corrected "Else context.success!" wording.

## D6 — SIX `context.fail!` exit points, not five (item 24)
Verified six `context.fail!` calls at `:23`, `:31`, `:40`, `:72`, `:79`, `:82`. `:79`
(`rescue Stripe::InvalidRequestError`, 'Invalid price ID provided') and `:82`
(`rescue StandardError`, different message) are two distinct exits by two distinct exception
classes. Changed "FIVE ... :79/:82" to "SIX ... :79, :82" with the distinction spelled out.

## D7 — `currentProductPrice` nested ternary / unnamed tiered SCREEN branch (item 9)
Verified `AccountBillingPlans.tsx:137-142` is a nested ternary branching on
`currentPriceObject.billingScheme === "tiered"` (`:139`): tiered branch reads
`currentPriceObject.tiers[0].unitAmount / 100.0` (`:140`), non-tiered reads
`currentPriceObject.unitAmount / 100.0` (`:141`), `null` fallback (`:142`). Replaced the
"simple `... : null`" description with the full nested ternary and named the tiered branch.

## D8 — off-by-one PlanCard element span (item 16)
Verified opening tag at `AccountBillingPlans.tsx:439`, self-closing `/>` at `:456`,
`);` of the return at `:457`. Changed "spans :439-457" to "spans :439-456" with the `:457`
clarification.
