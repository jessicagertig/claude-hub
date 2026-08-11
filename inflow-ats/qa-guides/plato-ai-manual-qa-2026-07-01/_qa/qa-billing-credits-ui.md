# QA — AI Credits Billing UI

Area: subscribe to an AI credit subscription, one-off credit top-ups, balance display, low/zero-credit
states, gating, and cancel / upgrade / downgrade / scheduled-change flows.

Primary surfaces:
- **Plato AI billing** — `/hire/settings/plato-ai/billing` (status banner + subscription tier cards + one-off top-up cards).
- **Plato AI usage** — `/hire/settings/plato-ai/usage` (balance breakdown + total + Buy credits).
- **Plan & billing** — `/hire/settings/billing` (AI-credits handoff callout + shared "Manage billing").

Conditions that hold for most cases below: an **admin** on an org with the `AI_APPLICANT_SUMMARY`
Flipper flag ON. Stripe-hosted pages (checkout redirect, customer portal) leave the app — verify the
**redirect happens** and the **return lands on the right page**; do not QA Stripe's own screens. Test in
both light and dark mode if convenient (every component is themed).

---

## 1. Access, flag gating & plan-feature behavior

- **Nav entry visibility** — "Plato AI" shows in the account-settings left nav only when the
  `AI_APPLICANT_SUMMARY` Flipper flag is on for the org. Flag off ⇒ no nav entry, and no AI-credits
  callout on Plan & billing.
- **Route is admin-gated, not flag-gated** — hitting `/hire/settings/plato-ai/billing` directly with the
  flag OFF still mounts the container; the real guard is admin-only. Verify a **non-admin** sees nothing
  (blank/null), and an **admin** still reaches the page even when the nav link is hidden.
- **Feature is a universal plan feature (NOT plan-tier gated)** — `AI_APPLICANT_SUMMARY` is a universal
  feature, so it is available on ALL plans (free included). Gating is the Flipper flag only. Verify the
  callout / Plato AI surfaces appear regardless of plan tier when the flag is on, and are NOT suppressed
  on a free / lower-tier plan. (Do not expect a "locked/upgrade" state driven by plan.)
- **Handoff callout placement** — the "AI credits — Manage AI credits" card renders at the bottom of Plan
  & billing on both the **subscribed** and **unsubscribed** plan pages, gated by the same flag. It is
  **absent on the free-trial** plan page. Clicking "Manage AI credits" navigates to
  `/hire/settings/plato-ai/billing`.

## 2. Billing page load & Stripe-return refresh

- **Initial load** — page shows a full-page "Loading…" spinner while prices fetch, then renders the status
  banner + subscription tier cards + one-off top-up cards. No flash of empty cards before prices resolve.
- **Return from successful checkout auto-refreshes** — landing on the billing page with
  `?ai_credit_subscribe_success` or `?ai_credit_top_up_success` in the URL must refresh balance,
  subscription, and purchase data so the banner/cards reflect the just-completed purchase with **no manual
  reload**. Fires once on mount.
- **Plain visit does not force-refetch** — visiting the page with no such query param must not trigger the
  refresh effect (only the normal price fetch).

## 3. Subscription status banner states

Condition-driven; the banner is one component covering all states.

- **Unsubscribed** — reads "No active subscription" / "Subscribe to start reviewing with Plato" /
  "Recurring monthly credits that roll over." with a "Manage billing" button.
- **Active subscription** — reads "Active subscription" / "{plan name} · {N} credits per month" / "Renews
  {date} · unused monthly credits roll over". Verify plan name and monthly credit count match the
  subscribed tier and the renew date is a real formatted date.
- **`past_due` still reads as subscribed** — an org whose subscription is `past_due` must render the active
  banner (not the "No active subscription" state), since active + past_due both count as subscribed.
- **Scheduled to cancel** — after cancelling, banner shows "Scheduled to cancel on {date}" and the button
  swaps to **"Don't cancel subscription"** (revert). The normal "Manage billing" button is hidden in this
  state.
- **Missing period-end date** — when a period-end is absent, the date copy falls back to **"next period"**
  rather than blank / `Invalid Date`.

## 4. Start a new subscription (unsubscribed org)

- **Subscribe goes straight to Stripe** — with no active subscription, each tier card shows "Subscribe"
  (primary). Clicking it goes **directly to a Stripe Checkout redirect** — there is **no in-app confirm
  modal** on the new-subscription path. Verify the redirect occurs.
- **Subscribe error** — a failed checkout-session create shows an error toast "Unable to start
  subscription." and the user stays on the page.
- **Section heading** — the subscription section subtitle reads **"Choose a credit subscription"** when
  unsubscribed (vs "Change your plan" when subscribed).

## 5. Change plan — upgrade / downgrade / change (active org)

Button text is derived from **credit count**, not dollar price: higher-credit tier → "Upgrade" (primary),
lower-credit tier → "Downgrade" (secondary), equal-credit tier → "Change plan" (secondary).

- **Per-tier button text & current card** — verify each non-current tier's button matches the rule above.
  The **current** tier card shows a "Current plan" badge and a **"Cancel"** button (not an action button).
- **Best-value badge** — the `_large` tier shows a "Best value" badge, unless it is the current plan (then
  "Current plan" wins).
- **Preview → confirm modal** — clicking Upgrade / Downgrade / Change first previews, then opens the
  "Confirm your update" modal. A failed preview shows toast "Unable to load subscription preview." and no
  modal opens.
- **Upgrade modal contents** — plan name + "{N} credits per month"; "Amount due today" (prorated); a
  **View details / Hide details** toggle revealing line items (new plan price, credit for current plan,
  total); the payment-method label ("{Brand} •••• {last4}"). Confirm button reads **"Confirm"**. On
  confirm ⇒ toast **"Plan upgraded successfully"**.
- **Downgrade modal contents** — a scheduled note ("Your subscription changes to {plan} at the end of your
  current billing period on {date}. You keep your current credits until then, and from that date you'll
  receive {N} credits each month instead of {M}."), the monthly price with payment-method label, and **no**
  amount-due-today / details toggle. Confirm button reads **"Confirm change"**. On confirm ⇒ toast **"Plan
  change scheduled"**.
- **Commit error** — a failed commit shows toast "Unable to change subscription. Please try again."
- **Number accuracy** — the modal's credit counts, prices, and the "instead of {M}" clause must match the
  selected tier and the real current plan's credits.

## 6. Scheduled change callout

- **Callout appears after a scheduled change** — once a change is scheduled (a downgrade schedules for
  period end), a callout above the tiers reads "Your plan will be downgraded from {current} to {scheduled}
  on {date}" (downgrade), or "Your plan will change to {scheduled} on {date}" (non-downgrade schedule).
  Verify from/to plan names and the date.
- **Cancel the scheduled change** — the "Don't downgrade plan" button cancels the pending schedule ⇒ toast
  "Scheduled change canceled", callout disappears, plan stays current. The button disables while the cancel
  is in flight.

## 7. Cancel & revert cancellation

- **Cancel confirm modal** — the current-plan card's "Cancel" opens the "Cancel subscription?" modal: body
  explains the subscription stops renewing, existing credits are kept, no further charge; a calendar callout
  reads "Will not renew on {date}" / "No new subscription credits after this date." Primary "Cancel
  subscription", secondary "Keep subscription". Verify the date matches the current period end (falls back
  to "next period" if absent).
- **Confirm cancel** — confirming ⇒ toast "Subscription canceled"; banner transitions to the "Scheduled to
  cancel on {date}" state; credits are retained (no immediate loss of access). On the current-plan tier
  card, the "Cancel" button is replaced by "Manage billing" once cancellation is scheduled.
- **Revert cancellation** — from the scheduled-to-cancel state, "Don't cancel subscription" ⇒ toast
  "Cancellation reverted"; banner returns to the normal active/renews state.

## 8. One-off credit top-up purchase

The buy path **forks on whether the org has a default payment method on Stripe**
(`stripeDefaultPaymentMethodOnFile`).

- **Card on file → in-app confirm modal** — "Buy credits" on a top-up card previews, then opens "Confirm
  your purchase": credit count, "One-time top-up, added to your balance.", "Amount due today", and a
  Payment method row ("{Brand} •••• {last4}", or "Card on file" when the brand/last4 are unavailable).
  Confirm ⇒ **direct charge** (no Stripe redirect).
- **Direct-charge success has no in-app confirm toast** — on the confirm path, the mutation's success fires
  **no toast**; the success growl arrives **via websocket** (`AI_CREDIT_TOP_UP_COMPLETE`) after the charge
  settles server-side, and the balance refreshes. Verify the modal closes and the balance updates rather
  than expecting an immediate onClick toast.
- **No card on file → Stripe Checkout** — with no default payment method, "Buy credits" **skips the modal**
  and redirects straight to Stripe Checkout. Returning with `?ai_credit_top_up_success` refreshes the
  balance (case 2).
- **Preview error (card on file)** — a failed preview shows toast "Unable to load purchase preview." and no
  modal.
- **Checkout-session error (no card)** — a failed checkout-session create shows toast "Failed to create
  checkout session".
- **Card contents** — each top-up card shows the dollar price, "{N} credits", and a "one-time" label;
  verify the credit numbers match the configured packs. The section hint states credits are available
  immediately and roll over each month.

## 9. Balance display & low / zero-credit states (Usage tab)

- **Three-source breakdown** — Usage shows a segmented bar + three rows in this order and copy: **Monthly
  plan credits** ("Included with your plan · resets {date}, unused credits do not roll over"), **Subscription
  credits** ("From your AI credit subscription · resets {date}, unused credits roll over"), **Top-up
  credits** ("One-time purchases · roll over, used after monthly and subscription credits run out"). Verify
  each row's remaining count and reset date; reset dates fall back to "next period" when a period-end is
  absent.
- **Total + Buy credits** — the total row shows "{N} credits total" (raw total, comma-formatted) and a
  "Buy credits" button that navigates to the Plato AI billing page.
- **Spend-order copy** — the section intro states credits are spent monthly-plan → subscription add-on →
  top-up; verify it matches the row order and the "used after … run out" description on top-ups.
- **Zero-balance state** — with all three buckets at 0, the total reads "0 credits total", every row shows
  0, and the segmented bar renders empty (no divide-by-zero artifact / no stray filled segment).
- **Large-number formatting** — thousands are comma-formatted (e.g. `2,500`) in both the source rows and
  the total.

## 10. Manage billing — SHARED / regression

`ManageBillingActions` now owns the Stripe portal-session call internally (moved off a parent-supplied
callback) and takes a `returnUrl`. This button is shared with the standard non-AI Plan & billing page.

- **Standard (non-AI) Plan & billing** — the ordinary "Manage billing" button must still open the Stripe
  customer portal and, on return, land back on `/hire/settings/billing` (the default returnUrl). This is
  the top regression risk in this slice.
- **Plato AI pages** — "Manage billing" from the subscription banner (unsubscribed → returns to
  `/hire/settings/billing`; subscribed → returns to `/hire/settings/plato-ai/billing`) and from the
  current-plan card in the scheduled-to-cancel state (returns to `/hire/settings/plato-ai/billing`).
- **Portal error** — a failed portal-session create shows toast "Unable to access billing portal." rather
  than a dead button.
- **Promo-code menu intact** — the "Use promo code" dropdown still appears where it did (active subscription
  without an applied coupon) and is unaffected by the refactor.

## 11. Double-submit / loading guards

- **Tier card buttons** — action buttons disable while any subscription mutation is in flight (subscribe /
  preview / commit / a scheduled downgrade) and show a loading state while the customer subscription is
  refetching. Rapid clicks must not fire duplicate previews / commits.
- **One-off Buy button** — disables/loads while a purchase (direct charge or checkout-session) is in flight.
- **Confirm modals dismiss before the charge fires** — both the subscription-change modal and the top-up
  confirm modal call `removeModal()` **before** firing their mutation, so the modal is gone the instant
  Confirm is clicked. Verify a fast double-click on Confirm cannot fire two charges / two subscription
  changes. This is the highest-risk double-submit path (the confirm buttons' own loading prop is frozen at
  open time and cannot be relied on — dismissal is what prevents the double-submit).
- **Scheduled-change cancel** — the "Don't downgrade plan" button disables while its cancel is in flight.
