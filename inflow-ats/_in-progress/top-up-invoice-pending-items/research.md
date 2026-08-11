# Research: top-up invoices sweeping in accrued per-job subscription charges

**Date:** 2026-07-30
**Read from:** `/Users/jessica/wrk/wrk-corp/inflow-ats.cross-subdomain-user-cookie` (billing code identical to `develop`)
**Status:** research only — nothing changed, no branch created

## The reported behavior

A customer bought the first AI credit one-off top-up. The invoice we created for it also picked up the per-job subscription charges that had accrued so far. We don't want that.

## Root cause

All three "charge the card on file" flows do the same two steps, in the same order:

```ruby
invoice_item = Stripe::InvoiceItem.create(
  customer: organization.stripe_customer_id,   # no `invoice:` — so this item is PENDING
  amount: amount, ...
)

invoice = Stripe::Invoice.create(
  customer: organization.stripe_customer_id,   # no pending_invoice_items_behavior
  collection_method: 'charge_automatically', ...
)

paid_invoice = Stripe::Invoice.pay(invoice.id)
```

An invoice item created **without** an `invoice:` parameter is a *pending* item on the customer. When an invoice is then created for that customer with no `pending_invoice_items_behavior`, every pending item on the customer is swept onto it — including the prorated per-job subscription charges Stripe has been accruing daily.

### The three call sites — identical defect in all three

| Flow | File | Lines |
|---|---|---|
| AI credit one-off top-up | `app/models/organization_ai_credit_purchase.rb` | `83-108` (`charge_for_purchase`) |
| We Work Remotely listing | `app/models/board_wwr_listing.rb` | `130-156` |
| WhatJobs listing | `app/models/board_what_jobs_listing.rb` | `172-191` |

Only the top-up has been observed failing, because it is the only one a per-job subscription customer has exercised so far. The other two are the same code shape and would behave identically.

## The API version pin is the crux

`config/initializers/stripe.rb:4`:

```ruby
Stripe.api_version = '2020-03-02'
```

Gem is `stripe (9.4.0)` (`Gemfile.lock:556`).

Current Stripe docs state that `pending_invoice_items_behavior` on invoice create **"Defaults to `exclude` if the parameter is omitted."** That is today's default. The behavior observed on this account — pending items being swept in — is the older default, consistent with the `2020-03-02` pin.

**Not determined:** which dated API version flipped that default, and whether `pending_invoice_items_behavior` is even honored on a request sent with `Stripe-Version: 2020-03-02`. The Stripe changelog search did not surface an entry for this parameter. This matters only for fix option A below; option B sidesteps it.

Also noted: Stripe's own docs use two spellings — `pending_invoice_items_behavior` (plural, on the invoice create reference) and `pending_invoice_item_behavior` (singular, in the invoice item reference's description of the `invoice` parameter). Confirm the exact accepted spelling before relying on it.

## Reproduced locally, 2026-07-30

Org 16 "Testing III" (`plan_simple_ats_per_job`, customer `cus_UVLVUoxmM4JhHX`), on the unfixed code. Publishing a third job mid-cycle put two proration invoice items in the pending pool; buying a $79.00 top-up then swept them in.

Confirm modal showed the top-up price. The invoice charged $88.62.

Invoice `in_1Tz3g5AsxjgRMuPmSLpWIq10`, `status: paid`, `billing_reason: manual`, `description: "AI Credit Top-Up"`:

```
 7900 | proration=false | invoiceitem | AI Credit Top-Up — ai_credit_pack_top_up_large
-1922 | proration=true  | invoiceitem | Unused time on 2 × Polymer after 13 Aug 2026
 2884 | proration=true  | invoiceitem | Remaining time on 3 × Polymer after 13 Aug 2026
total 8862 · amount_paid 8862
```

### Two consequences found during the reproduction

**Our record disagrees with the charge.** `OrganizationAiCreditPurchase` 21 has `stripe_amount = 7900`, because `charge_for_purchase` writes the price it looked up (`organization_ai_credit_purchase.rb:110`) rather than the invoice total. The database says $79.00 for a customer billed $88.62. Not addressed by the fix below — the fix makes them agree by making the invoice equal the price, but the write itself still records the wrong source.

**The raw lookup key is customer-visible.** The line reads `AI Credit Top-Up — ai_credit_pack_top_up_large`. `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` holds only `:kind` and `:credits`/`:credits_per_period` (`organization_ai_credit_purchase.rb:4-13`), so `dig(lookup_key, :name)` is always nil and the `|| stripe_price_lookup_key` fallback always fires. Pre-existing and independent of this bug. The same expression appears at `organization_ai_credit_purchases_controller.rb:159`.

Also noted: an orphan purchase record 20, `stripe_amount = 0`, `stripe_invoice_paid = false`, no `stripe_invoice_id`.

## The fix — three parts, all required together

Neither half works alone. `pending_invoice_items_behavior: 'exclude'` on its own would exclude our own charge, because it is pending too. Reordering on its own would not help either, because the prorations are already in the pool when `Invoice.create` runs, so the "empty" draft would come back carrying them.

```ruby
invoice = Stripe::Invoice.create(
  customer: organization.stripe_customer_id,
  collection_method: 'charge_automatically',
  pending_invoice_items_behavior: 'exclude',   # 1. draft comes back genuinely empty
  description: 'AI Credit Top-Up',
  metadata: { ... }
)

invoice_item = Stripe::InvoiceItem.create(
  customer: organization.stripe_customer_id,
  invoice: invoice.id,                         # 2. born attached, never enters the pool
  amount: amount,
  currency: 'usd',
  description: @description,
  metadata: { ... }
)

paid_invoice = Stripe::Invoice.pay(invoice.id) # 3. unchanged
```

1. **`pending_invoice_items_behavior: 'exclude'`** — keeps the accrued prorations off the new invoice.
2. **`invoice: invoice.id` on the item** — the item is attached to this specific draft rather than floating in the customer pool, so `exclude` does not drop it. This is why the two calls must swap: you cannot reference an invoice ID before the invoice exists.
3. **`Stripe::Invoice.pay` is unchanged.**

Stripe's invoice item reference on the `invoice` parameter:

> "The ID of an existing invoice to add this invoice item to. For subscription invoices, when left blank, the invoice item will be added to the next upcoming scheduled invoice. For standalone invoices, the invoice item won't be automatically added unless you pass `pending_invoice_item_behavior: 'include'` when creating the invoice. This is useful when adding invoice items in response to an invoice.created webhook. You can only add invoice items to draft invoices and there is a maximum of 250 items per invoice."

### Per-request API version override

`pending_invoice_items_behavior` may not be honored at the pinned `2020-03-02`. Per Jessica, the pin exists precisely so specific calls can pass a newer version when needed, so this is the sanctioned mechanism rather than a workaround:

```ruby
Stripe::Invoice.create(params, { stripe_version: '<version that supports it>' })
```

Determine the minimum version that supports the parameter before choosing one. Note that the override also changes the shape of the returned invoice object for that call — this code reads only `invoice.id` from it, so the exposure is small, but confirm that when picking the version.

**No longer an open question:** whether `Stripe::Invoice.pay` auto-finalizes a draft at this API version. The current code already creates a draft and immediately pays it, in production, at this pin — so it does.

`update_columns(stripe_invoice_id:, stripe_invoice_item_id:, stripe_amount:)` at `organization_ai_credit_purchase.rb:110` is unchanged; both IDs still exist, just assigned in the other order.

## AI credit subscriptions — no change needed

**Settled by Jessica:** the invoice Stripe creates for a Checkout subscription does not sweep the customer's pending invoice items. Stripe avoids it on its own. The AI credit subscription path needs no fix.

The path, for reference:

The AI credit subscription does **not** go through `Stripe::Invoice.create` at all. `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:35-60` builds a Checkout Session:

```ruby
default_options = {
  customer_email: customer_email,
  customer: current_organization.stripe_customer_id,
  mode: 'subscription',
  payment_method_types: ['card'],
  success_url: "...", cancel_url: "...",
  metadata: { organization_id:, organization_name:, ai_credit_pack_subscription: 'true' }
}
subscription_options = {
  line_items: [{ price: price.id, quantity: 1 }],
  subscription_data: { metadata: { ... } }
}
session = Stripe::Checkout::Session.create(default_options.merge(subscription_options))
```

Stripe creates the subscription and its first invoice server-side; the app never constructs that invoice.

Related but distinct, on the AI subscription upgrade path — `organization_ai_credit_purchases_controller.rb:324` passes `subscription_proration_behavior: 'always_invoice'` and `:454` passes `proration_behavior: 'always_invoice'`. Those deliberately invoice the proration immediately on an upgrade. Not the same bug, but worth reviewing in the same pass since they also decide when a customer gets charged.

## What was not investigated

- The per-job subscription code that produces the accruing prorations. Taken as given from Jessica's description.
- Whether any already-issued invoice needs correcting for the customer who hit this.
- Whether a test-mode reproduction is wanted before implementing.

## Sources

- [Stripe API — Create an invoice](https://docs.stripe.com/api/invoices/create)
- [Stripe API — Create an invoice item](https://docs.stripe.com/api/invoiceitems/create)
