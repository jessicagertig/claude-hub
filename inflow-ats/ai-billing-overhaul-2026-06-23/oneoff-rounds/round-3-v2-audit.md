# One-Off Purchase — Round 3 Audit (v2)

Confirmed: WWR `useCreateBoardWwrListing` invalidates `["jobs", data.id]` (useJob.ts:282), and `useCreateWwrCheckoutSession` is bare (useWwrListing.ts:29). My findings are accurate.

I have completed the full structural trace and comparison. Let me compile the final report. I'll filter out the items where current code actually conforms (those were stale in the trace's "OURS" and the current code now matches the analog — I'll fold the most important "now-conforms" notes into a short conformance section so the caller knows they were checked) and present the genuine deviations.

---

## DEVIATIONS: Current AI-credit one-off code vs WWR/WhatJobs analog

Chains traced:
- Backend: `organization_ai_credit_purchases_controller.rb` → `organization_ai_credit_purchase.rb` → `stripe_webhook_handler_job.rb` → `apply_ai_credit_purchase.rb`
- Analog: `board_wwr_listings_controller.rb` → `board_wwr_listing.rb` → `stripe_webhook_handler_job.rb`; `board_what_jobs_listings_controller.rb` → `board_what_jobs_listing.rb`
- Frontend: `AiCreditSubscription.tsx` → `useOrganizationAiCreditPurchase.ts`
- Analog FE: `JobDistributionWeWorkRemotely.tsx` → `useJob.ts`/`useWwrListing.ts`; `WhatJobsSidebarActions.tsx` → `useWhatJobsListing.ts`

All paths in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

### Webhook / post-payment business work

DEVIATION: finalize choke-point ordering | ANALOG: handler finalizes payment BEFORE doing business work — WWR `listing.finalize_stripe_payment` (`app/jobs/stripe_webhook_handler_job.rb:239`) then `listing.create_on_wwr` (`:240`); WhatJobs finalize (`:252`) before `create_on_what_jobs` (`:258`) | OURS: handler grants credits FIRST via `ApplyAiCreditPurchase.call(...)` (`app/jobs/stripe_webhook_handler_job.rb:213`) then finalizes via `result.purchase&.finalize_stripe_payment` (`:228`) — reversed order

DEVIATION: notification + broadcast placement | ANALOG: the post-payment notification and growl live in the model method the handler calls — `Notification::PaidWwrListingCreatedJob.perform_later(...)`, `broadcast_event`, `broadcast_show_growl` inside `BoardWwrListing#create_on_wwr` (`app/models/board_wwr_listing.rb:193-196`); WhatJobs `broadcast_event` from the handler (`stripe_webhook_handler_job.rb:256`) | OURS: `Notification::PaidAiCreditPackPurchasedJob.perform_later(...)` and the growl `GlobalChannel.broadcast_to(...)` live inside the interactor `ApplyAiCreditPurchase#apply_one_off` (`app/interactors/apply_ai_credit_purchase.rb:98-105`), not in the handler or a model method it calls

DEVIATION: webhook discriminator key | ANALOG: branch is selected by presence of the record-id metadata key itself — `object.metadata['board_wwr_listing_id'].present?` (`stripe_webhook_handler_job.rb:232`), `object.metadata['board_what_jobs_listing_id'].present?` (`:245`) | OURS: branch is selected by a separate boolean-string flag `object.metadata['ai_credit_pack_top_up'] == 'true'` (`stripe_webhook_handler_job.rb:212`), with the record id passed independently as `purchase_id: object.metadata['organization_ai_credit_purchase_id']` (`:218`); the flag is also checked BEFORE both listing branches

DEVIATION: record resolution in webhook path | ANALOG: single direct find — `BoardWwrListing.find(object.metadata.board_wwr_listing_id.to_i)` (`stripe_webhook_handler_job.rb:235-236`); `BoardWhatJobsListing.find(...)` (`:248-249`) | OURS: triple fallback resolver in `apply_one_off` — `find_by(id: purchase_id)` then `find_by(stripe_checkout_session_id:)` then `find_by(stripe_invoice_id:)` (`app/interactors/apply_ai_credit_purchase.rb:46-51`)

DEVIATION: grant-once guard | ANALOG: no ledger/transaction existence guard; only a publish guard (`return unless wwr_listing_id.blank?`, `board_wwr_listing.rb:174`; `return unless draft?`, `board_what_jobs_listing.rb:206`) | OURS: explicit ledger-existence idempotency guard `return if existing.ai_credit_balance_transactions.exists?(entry_type: :one_off_credit_pack_purchase_credit)` (`app/interactors/apply_ai_credit_purchase.rb:64`)

### Price model

DEVIATION: charge amount source | ANALOG: amount hardcoded in model and charged as `amount:` cents — `Stripe::InvoiceItem.create({ ..., amount: amount, currency: 'usd', ... })` (`board_wwr_listing.rb:130-133`) with `calculate_charge_amount` (`:84-94`); WhatJobs `amount: amount` (`board_what_jobs_listing.rb:172-175`), `calculate_charge_amount` = `17_500` (`:151-153`) | OURS: no `calculate_charge_amount`; model resolves a Stripe Price by lookup key `Stripe::Price.list(lookup_keys: [stripe_price_lookup_key], ...)` (`app/models/organization_ai_credit_purchase.rb:129`) and charges `price: price.id` (`:139`), reading `amount = price.unit_amount` (`:133`) only to stamp the column

DEVIATION: duplicate Stripe::Price.list call | ANALOG: model `charge_for_listing` makes NO Stripe::Price call (`board_wwr_listing.rb:112-163`) | OURS: `charge_for_purchase` issues a Stripe::Price.list (`organization_ai_credit_purchase.rb:129`) duplicating the one already done in the controller (`organization_ai_credit_purchases_controller.rb:84`) — two network calls resolving the same price

DEVIATION: checkout line_items shape | ANALOG: inline pricing — `line_items: [{ price_data: { currency: 'usd', product_data: { name:, description: }, unit_amount: amount }, quantity: 1 }]` (`board_wwr_listings_controller.rb:83-93`; WhatJobs `board_what_jobs_listings_controller.rb:224-234`) | OURS: Stripe Price reference — `line_items: [{ price: price.id, quantity: 1 }]` (`organization_ai_credit_purchases_controller.rb:163`)

DEVIATION: stamped stripe_amount value | ANALOG: stamps the locally-computed charge amount, `update_columns(..., stripe_amount: amount)` (`board_wwr_listing.rb:158`; `board_what_jobs_listing.rb:193`) | OURS: stamps `stripe_amount: amount` where `amount = price.unit_amount` (`organization_ai_credit_purchase.rb:133`,163) — the Stripe Price's unit_amount, not `paid_invoice.amount_paid`

### Stripe metadata payloads

DEVIATION: InvoiceItem/Invoice metadata keys | ANALOG: record-id key only — InvoiceItem `metadata: { board_wwr_listing_id: id }` (`board_wwr_listing.rb:135-137`), Invoice `metadata: { board_wwr_listing_id: id }` (`:148-150`); WhatJobs identical with `board_what_jobs_listing_id` (`board_what_jobs_listing.rb:177-179`,186-188) | OURS: both carry `{ organization_id, organization_ai_credit_purchase_id, stripe_price_lookup_key, ai_credit_pack_top_up: 'true' }` (`organization_ai_credit_purchase.rb:141-146`,153-158) — adds `organization_id`, `stripe_price_lookup_key`, and the `ai_credit_pack_top_up` flag beyond the sanctioned record-id rename

DEVIATION: checkout-session metadata keys | ANALOG: all three metadata blocks carry `{ <record_id>, organization_id, job_id }` (`board_wwr_listings_controller.rb:94-114`; `board_what_jobs_listings_controller.rb:235-256`) | OURS: all three carry `{ organization_ai_credit_purchase_id, organization_id, stripe_price_lookup_key, ai_credit_pack_top_up: 'true' }` (`organization_ai_credit_purchases_controller.rb:164-189`) — adds `stripe_price_lookup_key` + `ai_credit_pack_top_up` flag (and omits `job_id`, expected — no job)

DEVIATION: InvoiceItem `currency` key | ANALOG: explicit `currency: 'usd'` on the InvoiceItem (`board_wwr_listing.rb:133`; `board_what_jobs_listing.rb:175`) | OURS: omitted from `charge_for_purchase`'s InvoiceItem (`organization_ai_credit_purchase.rb:137-147`) — currency implied by `price: price.id`

### Controller / model authorization & naming

DEVIATION: direct-charge authorization | ANALOG: WWR `#create` authorizes the record — `authorize @listing` → `BoardWwrListingPolicy#create?` → `is_org_admin?` (`board_wwr_listings_controller.rb:19`); WhatJobs uses `authorize :billing, :checkout?` (`board_what_jobs_listings_controller.rb:133`) | OURS: `#charge_top_up` uses `authorize :billing, :checkout?` (`organization_ai_credit_purchases_controller.rb:76`) — matches WhatJobs, diverges from the WWR primary analog; there is no `OrganizationAiCreditPurchasePolicy` record-level charge authorization

DEVIATION: model charge method name | ANALOG: `charge_for_listing` (`board_wwr_listing.rb:112`; `board_what_jobs_listing.rb:156`) | OURS: `charge_for_purchase` (`organization_ai_credit_purchase.rb:124`) — `for_listing` → `for_purchase` is a record-type rename, not covered by the sanctioned `ai_credit_*` descriptor rename

DEVIATION: charge-on-update callback | ANALOG: WWR re-charges on update — `after_update :handle_after_update` → `charge_for_listing unless stripe_invoice_paid` (`board_wwr_listing.rb:9`,67-72) | OURS: `OrganizationAiCreditPurchase` has no charge-triggering callback; charge fires only from the explicit controller call (`organization_ai_credit_purchases_controller.rb:110`). Diverges from WWR primary only (WhatJobs has no charge-on-update callback either)

DEVIATION: pre-charge validation interactor | ANALOG (WhatJobs): runs `ValidateWhatJobsListing.call(listing:, job:)` and bails before charging (`board_what_jobs_listings_controller.rb:156-160`,207-211) | OURS: no pre-charge validation interactor; validates only lookup key + Stripe price presence (`organization_ai_credit_purchases_controller.rb:79-89`,132-142). Diverges from WhatJobs secondary only (WWR primary has none)

### Frontend

DEVIATION: toast before Stripe redirect | ANALOG: checkout onSuccess redirects with no toast — WWR `onSuccess: (data) => { window.location.href = data.url }` (`JobDistributionWeWorkRemotely.tsx:337-340`); WhatJobs identical (`WhatJobsSidebarActions.tsx:133-145`) | OURS: `handleCreateTopUpCheckoutSession` onSuccess calls `redirectToStripe(...)` (`AiCreditSubscription.tsx:193`), which fires `addToast({ title: "Redirecting to Stripe checkout...", kind: "success" })` before redirecting (`AiCreditSubscription.tsx:65-68`)

DEVIATION: direct-charge invalidation target | ANALOG: WWR `useCreateBoardWwrListing` invalidates `["jobs", data.id]` (`useJob.ts:280-282`); WhatJobs `useCreatePaidBoardWhatJobsListing` invalidates `["boardWhatJobsListings", jobId]` (`useWhatJobsListing.ts:134-136`) | OURS: `useChargeAiCreditTopUp` invalidates `["organizationAiCreditBalance"]` (`useOrganizationAiCreditPurchase.ts:110-112`) — parallel pattern, different read model (credit balance vs job/listing); divergence forced by the domain object

### Whitelisted (reported for completeness, NOT actionable)

DEVIATION: double-charge guard 2nd predicate | ANALOG: `stripe_invoice_id.present? && is_active?`/`&& live?` (`board_wwr_listing.rb:115`; `board_what_jobs_listing.rb:160`) | OURS: `stripe_invoice_id.present? && stripe_invoice_paid?` (`organization_ai_credit_purchase.rb:126`) — WHITELIST item 1

### Conformance notes (current code matches analog; the trace's stale "OURS" section described otherwise)

- Two controller actions split by payment method (`charge_top_up` + `create_top_up_checkout_session`, controller:75,128; routes:193-194) and FE two-endpoint branching in `handleBuyPack` (`AiCreditSubscription.tsx:206-224`) now mirror the WWR/WhatJobs `create`+`create_checkout_session` structure. The stale "OURS" described a single `purchase_top_up` action with controller-side branching.
- Checkout response is `{ url: session.url, sessionId: session.id }, status: :created` (controller:194), matching the analog's `{ url, sessionId }` (`board_wwr_listings_controller.rb:120`; `board_what_jobs_listings_controller.rb:261`); FE reads `data.url` (`AiCreditSubscription.tsx:193`). Stale "OURS" described `{ redirectUrl: session.url }`.
- Direct-charge renders the serialized record `render_one(purchase, OrganizationAiCreditPurchaseSerializer)` (controller:111), matching `render_one(@listing, ...)` (`board_wwr_listings_controller.rb:23`). Stale "OURS" described `render json: { charged: true }`.
- `charge_for_purchase` Invoice omits `auto_advance` (model:149-159), matching the analog. Stale "OURS" showed `auto_advance: true`.
- `create_top_up_checkout_session` omits `payment_method_types` (controller:160-192), matching the analog. Stale "OURS" showed `payment_method_types: ['card']`.
- `useCreateAiCreditTopUpCheckoutSession` is a bare `useMutation` (hooks:126-128), matching the analog's bare checkout hooks.
- Record creation pre-stamps `last_updated_by_organization_user: current_organization_user` (controller:99,152), matching the analog's `last_updated_by_organization_user` stamp (`board_wwr_listings_controller.rb:11`); column exists via migration `20260611120003`. The interactor's growl-target fallback `existing.last_updated_by_organization_user_id.nil? ? organization.owner : ...` (`apply_ai_credit_purchase.rb:97`) mirrors `BoardWwrListing#broadcast_show_growl` (`board_wwr_listing.rb:272`).

Note: schema.rb (db/schema.rb:965-989) is stale — `stripe_invoice_paid`, `stripe_invoice_item_id`, `stripe_amount` (renamed from `amount_cents_paid`), and `last_updated_by_organization_user_id` exist only via migrations `20260611120002`/`20260611120003`, not in schema.rb. Out of scope for analog faithfulness but flagged since the model/code depend on those columns.
