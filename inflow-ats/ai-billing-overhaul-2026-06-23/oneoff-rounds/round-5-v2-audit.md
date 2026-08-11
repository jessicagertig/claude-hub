# One-Off Purchase — Round 5 Audit (v2)

The button has `loading`/`disabled` props correctly. No deviation there.

I now have a complete structural comparison. Let me compile the final findings. 

My investigation traced these chains:
- Backend direct charge: `AiCreditSubscription.tsx → useOrganizationAiCreditPurchase.ts (useChargeAiCreditTopUp) → api.ts → routes.rb:193 → organization_ai_credit_purchases_controller.rb:charge_top_up → organization_ai_credit_purchase.rb:charge_for_purchase → Stripe` vs analog `JobDistributionWeWorkRemotely.tsx → useJob.ts (useCreateBoardWwrListing) → routes.rb:233 → board_wwr_listings_controller.rb:create → board_wwr_listing.rb:charge_for_listing`
- Backend checkout: `useOrganizationAiCreditPurchase.ts (useCreateAiCreditTopUpCheckoutSession) → routes.rb:194 → organization_ai_credit_purchases_controller.rb:create_top_up_checkout_session` vs analog `useWwrListing.ts → routes.rb:235 → board_wwr_listings_controller.rb:create_checkout_session`
- Webhook: `stripe_webhook_handler_job.rb:212 (ai branch) → ApplyAiCreditPurchase` vs analog `stripe_webhook_handler_job.rb:234 (wwr branch) → finalize_stripe_payment + create_on_wwr`
- Interactor: `apply_ai_credit_purchase.rb:apply_one_off`

After a comprehensive structural comparison, the current code is largely faithful to the WWR/WhatJobs analog (two-action split matching `#create`/`#create_checkout_session`, create-then-charge order, model method doing Stripe, three-step InvoiceItem/Invoice/pay, `update_columns` stamping, `finalize_stripe_payment` choke point in webhook, metadata-id webhook lookup). The genuine non-sanctioned, non-whitelisted deviations are in the save-failure error-rendering shape.

**DEVIATION: Direct-charge path save-failure error rendering**
| Aspect | Analog | Ours |
|--------|--------|------|
| Analog | On record save failure, `BoardWwrListingsController#create` renders the record's field-level validation errors via `render_errors(@listing)` inside the `if @listing.save ... else render_errors(@listing)` branch (board_wwr_listings_controller.rb:21, 24-25). | `OrganizationAiCreditPurchasesController#charge_top_up` discards the record's errors and renders a fixed generic string via `render_general_errors(['Failed to create purchase record'])` (organization_ai_credit_purchases_controller.rb:101-104). The AR errors are only logged, not returned to the client. |

**DEVIATION: Checkout-session path save-failure error rendering**
| Aspect | Analog | Ours |
|--------|--------|------|
| Analog | On record save failure, `BoardWwrListingsController#create_checkout_session` renders the record's field-level validation errors via `render_errors(@listing)` inside the `if @listing.save ... else render_errors(@listing)` branch (board_wwr_listings_controller.rb:76, 121-122). | `OrganizationAiCreditPurchasesController#create_top_up_checkout_session` discards the record's errors and renders a fixed generic string via `render_general_errors(['Failed to create purchase record'])` (organization_ai_credit_purchases_controller.rb:156-159). The AR errors are only logged, not returned to the client. |

Everything else in the one-off purchase flow (frontend branching + confirm modal, two-action controller split, create-then-charge ordering, `authorize purchase` via `OrganizationAiCreditPurchasePolicy#create?` mirroring WWR's `authorize @listing`, the model `charge_for_purchase` doing the three-step `Stripe::InvoiceItem.create` → `Stripe::Invoice.create` → `Stripe::Invoice.pay` → `update_columns` stamping, the compound double-charge guard shape, the checkout-session Stripe shape, the `{ url, sessionId }` response read as `data.url`, the `invoice.paid` webhook finding the record by `organization_ai_credit_purchase_id` metadata then calling `finalize_stripe_payment` as the choke point + `ApplyAiCreditPurchase` mirroring `create_on_wwr`, and the interactor grant-once guard) is structurally faithful to the WWR/WhatJobs analog or falls under the sanctioned deviations (PurchaseAiCreditTopUpConfirmModal, OrganizationAiCreditPurchase record source incl. its `currency` column write, `ai_credit_*` descriptor naming) or the whitelist (the `stripe_invoice_paid?` second predicate of the double-charge guard, the `["organizationAiCreditBalance"]` direct-charge invalidation target, the `price: price.id` Stripe-resolved pricing vs hardcoded `unit_amount`/`price_data`, the grant-once / charge-on-update / schema.rb-staleness items).

Relevant files:
- /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb
- /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/board_wwr_listings_controller.rb (analog)
