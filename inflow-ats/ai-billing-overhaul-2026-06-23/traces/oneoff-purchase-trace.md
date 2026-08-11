# One-Off Purchase (Direct Charge + Checkout Session) -- Iota-for-Iota Structural Trace

Goal: an exact structural map of the ANALOG one-off purchase flows (WWR primary, WhatJobs secondary) and OURS (AI credit top-up), so deviations can be named precisely. This is a TRACE/SPEC. No code is implemented here.

The ANALOG is the WeWorkRemotely one-off listing purchase: `BoardWwrListingsController#create` (direct charge path when payment method on file) and `#create_checkout_session` (no card path). OURS is the AI credit one-off top-up: `OrganizationAiCreditPurchasesController#purchase_top_up` (both paths in one action). The WhatJobs analog (`BoardWhatJobsListingsController#create_paid_listing` + `#create_checkout_session`) is traced as a secondary reference.

---

## ANALOG (WWR) -- full skeleton

Two entry paths converge: if the org has a payment method on file, the frontend calls `#create` which saves a listing then calls `charge_for_listing` (direct charge via Invoice API). If no payment method, the frontend calls `#create_checkout_session` which saves a listing then creates a `Stripe::Checkout::Session` in `payment` mode. Both paths converge at the `invoice.paid` webhook which calls `finalize_stripe_payment` then `create_on_wwr`.

### Path A: Direct Charge (payment method on file)

Ordered identifier chain (frontend entry -> hook -> apiPost -> route -> controller -> model -> Stripe):

1. `JobDistributionWeWorkRemotely` (component) -- `app/javascript/ats/src/views/jobApplications/jobDistribution/JobDistributionWeWorkRemotely.tsx:109`
2. `hasPaymentMethod` -- `JobDistributionWeWorkRemotely.tsx:163` -> `currentOrganization.stripeDefaultPaymentMethodOnFile` (from `Organization` serializer attr `:stripe_default_payment_method_on_file`, `app/serializers/api/v1/organization_serializer.rb:22`)
3. `handleClickOnCheckout` -- `JobDistributionWeWorkRemotely.tsx:215` -> validates category -> `handleSubmit`
4. `handleSubmit` -- `JobDistributionWeWorkRemotely.tsx:224` -> optionally updates org `wwrCompanyBio` -> `createOrUpdateWwrListing()`
5. `createOrUpdateWwrListing` -- `JobDistributionWeWorkRemotely.tsx:247` -> branch: `hasPaymentMethod` is true -> `handleCreateBoardWwrListing()`
6. `handleCreateBoardWwrListing` -- `JobDistributionWeWorkRemotely.tsx:259` -> `createBoardWwrListing({ jobId, wwrCategory, wwrJobListingType, wwrRegion, plan })`
7. `createBoardWwrListing` (const) -- `app/javascript/shared/queryHooks/useJob.ts:91` -> `apiPost({ path: '/jobs/${jobId}/board_wwr_listings', variables: { boardWwrListing } })`
8. `useCreateBoardWwrListing` (hook) -- `useJob.ts:278` -> `useMutation(createBoardWwrListing, ...)`
9. `apiPost` -- `app/javascript/shared/queryHooks/api.ts:25` -> `allKeysToSnake(variables)` -> POST
10. route `POST /api/v1/jobs/:job_id/board_wwr_listings` -- `config/routes.rb:232` (resources :board_wwr_listings, only: [:create, :update])
11. `BoardWwrListingsController#create` -- `app/controllers/api/v1/board_wwr_listings_controller.rb:5`
12. `exists(current_organization.jobs.where(id: params[:job_id]), ...)` -- `controller:6` -> scoped job lookup
13. Guard: `render_general_errors(['Job description cannot be blank']) if job.description.blank?` -- `controller:8`
14. `listing_params` -- `controller:133` -> `params.require(:board_wwr_listing).permit(:wwr_category, :wwr_job_listing_type, :wwr_region, :status, :plan, :logo)`
15. `temp_params = listing_params.merge({ last_updated_by_organization_user: current_organization_user })` -- `controller:11`
16. `@listing = job.board_wwr_listings.build(temp_params)` -- `controller:14` -> creates unsaved `BoardWwrListing`
17. `authorize @listing` -- `controller:19` -> `BoardWwrListingPolicy#create?` (`app/policies/board_wwr_listing_policy.rb:5`) -> `is_org_admin?` (`app/policies/application_policy.rb:50`)
18. `@listing.save` -- `controller:21` -> persists to DB. Triggers `after_update :handle_after_update` callback (but this is a CREATE, NOT an update -- `after_update` does NOT fire on create).
19. `@listing.charge_for_listing` -- `controller:22` (called AFTER save succeeds)
20. `render_one(@listing, Api::V1::BoardWwrListingSerializer)` -- `controller:23`
21. rescue `StandardError => e` -- `controller:28` -> `render_general_errors(["Unable to process payment: #{e.message}"])`

`BoardWwrListing#charge_for_listing` -- `app/models/board_wwr_listing.rb:112`:

22. `amount = calculate_charge_amount` -- `board_wwr_listing.rb:113` -> `calculate_charge_amount` (`:84`) -> hardcoded pricing: standard=29900, good=36800, better=40800, best=45800 cents, minus optional `wwr_percent_off` discount
23. Guard: `return if stripe_invoice_id.present? && is_active?` -- `board_wwr_listing.rb:115` (double-charge guard)
24. Guard: `return if organization.stripe_customer_id.blank?` -- `board_wwr_listing.rb:122`
25. `@description` / `@final_description` -- `board_wwr_listing.rb:124-126` -> human-readable invoice description
26. `Stripe::InvoiceItem.create(...)` -- `board_wwr_listing.rb:130`

Stripe InvoiceItem shape verbatim (`board_wwr_listing.rb:130-138`):
```ruby
{
  customer: organization.stripe_customer_id,
  amount: amount,
  currency: 'usd',
  description: @final_description,
  metadata: {
    board_wwr_listing_id: id
  }
}
```

27. `Stripe::Invoice.create(...)` -- `board_wwr_listing.rb:143`

Stripe Invoice shape verbatim (`board_wwr_listing.rb:143-151`):
```ruby
{
  customer: organization.stripe_customer_id,
  collection_method: 'charge_automatically',
  description: 'We Work Remotely Listing',
  metadata: {
    board_wwr_listing_id: id
  }
}
```

28. `Stripe::Invoice.pay(invoice.id)` -- `board_wwr_listing.rb:156` (synchronous pay)
29. `update_columns(stripe_invoice_id: invoice.id, stripe_invoice_item_id: invoice_item.id, stripe_amount: amount)` -- `board_wwr_listing.rb:158` -> stamps Stripe references, skips validations/callbacks
30. Returns `paid_invoice` -- `board_wwr_listing.rb:163`

Column writes from direct-charge path: `stripe_invoice_id`, `stripe_invoice_item_id`, `stripe_amount` (via `update_columns`).

### Path B: Checkout Session (no payment method on file)

Ordered identifier chain (frontend entry -> hook -> apiPost -> route -> controller -> Stripe):

1. `createOrUpdateWwrListing` -- `JobDistributionWeWorkRemotely.tsx:247` -> branch: `hasPaymentMethod` is false -> `handleCreateCheckoutSession()`
2. `handleCreateCheckoutSession` -- `JobDistributionWeWorkRemotely.tsx:326` -> `createCheckoutSession({ jobId, wwrCategory, wwrJobListingType, wwrRegion, plan })`
3. `createWwrCheckoutSession` (const) -- `app/javascript/shared/queryHooks/useWwrListing.ts:7` -> `apiPost({ path: '/jobs/${jobId}/board_wwr_listings/create_checkout_session', variables: { wwrCategory, wwrJobListingType, wwrRegion, plan } })`
4. `useCreateWwrCheckoutSession` (hook) -- `useWwrListing.ts:29` -> `useMutation(createWwrCheckoutSession)`
5. route `POST /api/v1/jobs/:job_id/board_wwr_listings/create_checkout_session` -- `config/routes.rb:234`
6. `BoardWwrListingsController#create_checkout_session` -- `board_wwr_listings_controller.rb:51`
7. `authorize :billing, :checkout?` -- `controller:52` -> `BillingPolicy#checkout?` (`app/policies/billing_policy.rb:12`) -> `is_org_admin?`
8. `exists(current_organization.jobs.where(id: params[:job_id]), ...)` -- `controller:54`
9. Guard: `render_general_errors(['Job description cannot be blank']) if job.description.blank?` -- `controller:55`
10. `checkout_listing_params` -- `controller:137` -> `params.permit(:wwr_category, :wwr_job_listing_type, :wwr_region, :plan, :job_id)` (NOTE: different from `listing_params` -- no `require(:board_wwr_listing)` wrapper)
11. Merge defaults: `{ last_updated_by_organization_user: current_organization_user, status: 'approved', stripe_invoice_paid: false }` -- `controller:59-63`
12. `@listing = job.board_wwr_listings.build(temp_params)` -- `controller:65`
13. `@listing.save` -- `controller:76` -> persists to DB with `stripe_invoice_paid: false`
14. `amount = @listing.calculate_charge_amount` -- `controller:77`
15. `Stripe::Checkout::Session.create(...)` -- `controller:80`

Stripe Checkout Session shape verbatim (`controller:80-118`):
```ruby
{
  customer: current_organization.stripe_customer_id,
  mode: 'payment',
  line_items: [{
    price_data: {
      currency: 'usd',
      product_data: {
        name: "#{job.title} - We Work Remotely Job Listing",
        description: @final_description
      },
      unit_amount: amount
    },
    quantity: 1
  }],
  payment_intent_data: {
    metadata: {
      board_wwr_listing_id: @listing.id,
      organization_id: current_organization.id,
      job_id: job.id
    }
  },
  invoice_creation: {
    enabled: true,
    invoice_data: {
      description: @final_invoice_description,
      metadata: {
        board_wwr_listing_id: @listing.id,
        job_id: job.id
      }
    }
  },
  metadata: {
    board_wwr_listing_id: @listing.id,
    organization_id: current_organization.id,
    job_id: job.id
  },
  success_url: "#{Variables::AtsRootUrl}/jobs/#{job.id}/distribution/weworkremotely?checkout=success&session_id={CHECKOUT_SESSION_ID}",
  cancel_url: "#{Variables::AtsRootUrl}/jobs/#{job.id}/distribution/weworkremotely?checkout=cancel&session_id={CHECKOUT_SESSION_ID}"
}
```

16. `render json: { url: session.url, sessionId: session.id }, status: :created` -- `controller:120`
17. Frontend `onSuccess`: `window.location.href = data.url` -- `JobDistributionWeWorkRemotely.tsx:339`
18. rescue `Stripe::StripeError` -- `controller:125` -> `render json: { error: e.message }, status: :unprocessable_entity`

Key differences between Path A and Path B:
- Path A: uses `listing_params` (requires `board_wwr_listing` key), `authorize @listing` (BoardWwrListingPolicy), `charge_for_listing` model method, response is serialized listing
- Path B: uses `checkout_listing_params` (no wrapping key), `authorize :billing, :checkout?` (BillingPolicy), `Stripe::Checkout::Session.create` in controller, response is `{ url, sessionId }`
- Path B sets `stripe_invoice_paid: false` on record creation; Path A does not set it (defaults to `false` per schema `board_wwr_listings.stripe_invoice_paid`, default: false)
- Path A uses `Stripe::InvoiceItem.create` + `Stripe::Invoice.create` + `Stripe::Invoice.pay` (hardcoded `amount` in cents); Path B uses `Stripe::Checkout::Session.create` with `price_data` (computed `unit_amount`)

### Webhook: invoice.paid (both paths converge here)

The `invoice.paid` webhook fires for BOTH the direct-charge `Stripe::Invoice.pay` call AND the checkout session's auto-created invoice.

Ordered chain (`app/jobs/stripe_webhook_handler_job.rb`):

1. `StripeWebhookHandlerJob#perform(event_id)` -- `stripe_webhook_handler_job.rb:14` -> `Stripe::Event.retrieve(event_id)` (`:20`) -> `handle_stripe_event(event)` (`:41`)
2. `handle_stripe_event` -- `stripe_webhook_handler_job.rb:44` -> `object = event.data.object` (`:48`)
3. `case event.type` -> `'invoice.paid'` -- `stripe_webhook_handler_job.rb:198`
4. Metadata check: `object.metadata&.[]('board_wwr_listing_id').present?` -- `stripe_webhook_handler_job.rb:233`
5. `listing_id = object.metadata.board_wwr_listing_id.to_i` -- `stripe_webhook_handler_job.rb:236`
6. `listing = BoardWwrListing.find(listing_id)` -- `stripe_webhook_handler_job.rb:237`
7. `listing.finalize_stripe_payment` -- `stripe_webhook_handler_job.rb:240` -> `BoardWwrListing#finalize_stripe_payment` (`board_wwr_listing.rb:166`) -> `update_columns(stripe_invoice_paid: true)`
8. `listing.create_on_wwr` -- `stripe_webhook_handler_job.rb:241` -> `BoardWwrListing#create_on_wwr` (`board_wwr_listing.rb:173`) -> creates listing on WWR API -> `update_columns(wwr_listing_id:, wwr_slug:, published_at:, expires_at:)` -> `broadcast_event('wwr_listing_published')` -> `broadcast_show_growl('Created WWR Listing')` -> `Notification::PaidWwrListingCreatedJob.perform_later(job.organization.id, job.id)`
9. `return` -- `stripe_webhook_handler_job.rb:243` (early return prevents fallthrough to subscription handler)

Webhook lookup key: `object.metadata['board_wwr_listing_id']` -- the record id stamped in both the direct-charge invoice metadata (`board_wwr_listing.rb:149`) and the checkout session's `invoice_data.metadata` (`board_wwr_listings_controller.rb:106`).

---

## ANALOG (WhatJobs) -- full skeleton (secondary reference)

The WhatJobs analog is structurally identical to WWR. Two entry paths: `create_paid_listing` (direct charge) and `create_checkout_session` (no card). Same three-step Stripe API pattern in the model's `charge_for_listing`. Same `invoice.paid` webhook convergence.

### Path A: Direct Charge (payment method on file)

1. `WhatJobsSidebarActions` (component) -- `app/javascript/ats/src/views/jobApplications/jobDistribution/WhatJobsSidebarActions.tsx:35`
2. `hasPaymentMethod` -- `WhatJobsSidebarActions.tsx:26` (passed as prop)
3. `handlePurchase` -- `WhatJobsSidebarActions.tsx:78` -> branch: `hasPaymentMethod` true -> `handleCreatePaidBoardWhatJobsListing()`
4. `handleCreatePaidBoardWhatJobsListing` -- `WhatJobsSidebarActions.tsx:94` -> `createPaidBoardWhatJobsListing({ jobId, boardWhatJobsListing: listingData })`
5. `createPaidBoardWhatJobsListing` (const) -- `app/javascript/shared/queryHooks/useWhatJobsListing.ts:54` -> `apiPost({ path: '/jobs/${jobId}/board_what_jobs_listings/create_paid_listing', variables: { boardWhatJobsListing } })`
6. `useCreatePaidBoardWhatJobsListing` (hook) -- `useWhatJobsListing.ts:131` -> `useMutation(createPaidBoardWhatJobsListing, ...)`
7. route `POST /api/v1/jobs/:job_id/board_what_jobs_listings/create_paid_listing` -- `config/routes.rb:241`
8. `BoardWhatJobsListingsController#create_paid_listing` -- `app/controllers/api/v1/board_what_jobs_listings_controller.rb:132`
9. `authorize :billing, :checkout?` -- `controller:133` -> `BillingPolicy#checkout?` -> `is_org_admin?`
10. `exists(current_organization.jobs.where(id: params[:job_id]), ...)` -- `controller:135`
11. `CreateOrUpdateWhatJobsListingWithIntegration.call(...)` -- `controller:141` -> interactor that builds/updates the listing record
12. `@listing = result.listing` -- `controller:153`
13. `ValidateWhatJobsListing.call(listing: @listing, job: job)` -- `controller:156` -> validation interactor
14. `@listing.charge_for_listing` -- `controller:163`
15. `render_one(@listing, Api::V1::BoardWhatJobsListingSerializer)` -- `controller:165`
16. rescue `WhatJobsApi::ValidationError` -- `controller:167` (renders listing errors); rescue `Stripe::StripeError` -- `controller:171`; rescue `StandardError` -- `controller:175`

`BoardWhatJobsListing#charge_for_listing` -- `app/models/board_what_jobs_listing.rb:156`:

17. `amount = calculate_charge_amount` -- `board_what_jobs_listing.rb:157` -> `17_500` ($175 flat)
18. Guard: `return if stripe_invoice_id.present? && live?` -- `board_what_jobs_listing.rb:160` (double-charge guard)
19. Guard: `return if organization.stripe_customer_id.blank?` -- `board_what_jobs_listing.rb:166`
20. `Stripe::InvoiceItem.create(...)` -- `board_what_jobs_listing.rb:172`

Stripe InvoiceItem shape verbatim (`board_what_jobs_listing.rb:172-180`):
```ruby
{
  customer: organization.stripe_customer_id,
  amount: amount,
  currency: 'usd',
  description: @description,
  metadata: {
    board_what_jobs_listing_id: id
  }
}
```

21. `Stripe::Invoice.create(...)` -- `board_what_jobs_listing.rb:182`

Stripe Invoice shape verbatim (`board_what_jobs_listing.rb:182-189`):
```ruby
{
  customer: organization.stripe_customer_id,
  collection_method: 'charge_automatically',
  description: 'WhatJobs Listing',
  metadata: {
    board_what_jobs_listing_id: id
  }
}
```

22. `Stripe::Invoice.pay(invoice.id)` -- `board_what_jobs_listing.rb:191`
23. `update_columns(stripe_invoice_id: invoice.id, stripe_invoice_item_id: invoice_item.id, stripe_amount: amount)` -- `board_what_jobs_listing.rb:193`

### Path B: Checkout Session (no payment method)

1. `handlePurchase` -- `WhatJobsSidebarActions.tsx:78` -> branch: `hasPaymentMethod` false -> `handleCreateCheckoutSession()`
2. `handleCreateCheckoutSession` -- `WhatJobsSidebarActions.tsx:126` -> `createCheckoutSession({ jobId, boardWhatJobsListing: listingData })`
3. `createWhatJobsCheckoutSession` (const) -- `useWhatJobsListing.ts:13` -> `apiPost({ path: '/jobs/${jobId}/board_what_jobs_listings/create_checkout_session', variables: { boardWhatJobsListing } })`
4. route `POST /api/v1/jobs/:job_id/board_what_jobs_listings/create_checkout_session` -- `config/routes.rb:240`
5. `BoardWhatJobsListingsController#create_checkout_session` -- `board_what_jobs_listings_controller.rb:180`
6. `authorize :billing, :checkout?` -- `controller:181`
7. Record creation via `CreateOrUpdateWhatJobsListingWithIntegration.call(...)` -- `controller:192`
8. `ValidateWhatJobsListing.call(...)` -- `controller:207`
9. `amount = @listing.calculate_charge_amount` -- `controller:216`
10. `Stripe::Checkout::Session.create(...)` -- `controller:221`

Stripe Checkout Session shape verbatim (`controller:221-259`):
```ruby
{
  customer: current_organization.stripe_customer_id,
  mode: 'payment',
  line_items: [{
    price_data: {
      currency: 'usd',
      product_data: {
        name: "#{job.title} - WhatJobs Job Listing",
        description: @description
      },
      unit_amount: amount
    },
    quantity: 1
  }],
  payment_intent_data: {
    metadata: {
      board_what_jobs_listing_id: @listing.id,
      organization_id: current_organization.id,
      job_id: job.id
    }
  },
  invoice_creation: {
    enabled: true,
    invoice_data: {
      description: @description,
      metadata: {
        board_what_jobs_listing_id: @listing.id,
        job_id: job.id
      }
    }
  },
  metadata: {
    board_what_jobs_listing_id: @listing.id,
    organization_id: current_organization.id,
    job_id: job.id
  },
  success_url: "#{Variables::AtsRootUrl}/jobs/#{job.id}/distribution/whatjobs?checkout=success&session_id={CHECKOUT_SESSION_ID}",
  cancel_url: "#{Variables::AtsRootUrl}/jobs/#{job.id}/distribution/whatjobs?checkout=cancel&session_id={CHECKOUT_SESSION_ID}"
}
```

11. `render json: { url: session.url, sessionId: session.id }, status: :created` -- `controller:261`
12. Frontend `onSuccess`: `window.location.href = data.url` -- `WhatJobsSidebarActions.tsx:144`

### Webhook: invoice.paid (WhatJobs branch)

1. Metadata check: `object.metadata&.[]('board_what_jobs_listing_id').present?` -- `stripe_webhook_handler_job.rb:246`
2. `listing_id = object.metadata.board_what_jobs_listing_id.to_i` -- `stripe_webhook_handler_job.rb:249`
3. `listing = BoardWhatJobsListing.find(listing_id)` -- `stripe_webhook_handler_job.rb:250`
4. `listing.finalize_stripe_payment` -- `stripe_webhook_handler_job.rb:253` -> `BoardWhatJobsListing#finalize_stripe_payment` (`board_what_jobs_listing.rb:200`) -> `update_columns(stripe_invoice_paid: true)`
5. `listing.broadcast_event('what_jobs_listing_payment_received')` -- `stripe_webhook_handler_job.rb:257`
6. `listing.create_on_what_jobs` -- `stripe_webhook_handler_job.rb:259` -> `BoardWhatJobsListing#create_on_what_jobs` (`board_what_jobs_listing.rb:204`) -> `mark_expired_as_inactive` (`:205`), guard `return unless draft?` (`:206`), then `WhatJobsListing.new.create_listing(self)` (`:208`, API call)
7. `return` -- `stripe_webhook_handler_job.rb:261`

---

## OURS -- full skeleton

One controller action handles both direct charge and checkout redirect. The frontend branching on payment method happens differently from the analog: in the analog, the frontend decides which controller action to call; in ours, the frontend always calls the same action and the controller checks `stripe_default_payment_method_on_file` on the org.

### Frontend entry (both paths)

Ordered identifier chain (frontend entry -> hook -> apiPost -> route -> controller):

1. `AiCreditSubscription` (component) -- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:27`
2. `pricesData` (prop) -- `AiCreditSubscription.tsx:27` -> passed from parent; populated via `useOrganizationAiCreditPurchasePrices` hook
3. `splitTiers(pricesData)` -- `AiCreditSubscription.tsx:51` -> `aiSubscriptionHelpers.ts:19` -> `aiCreditPrices(pricesData.data || [])` -> `planHelpers.ts:86`
4. `aiCreditPrices` -- `planHelpers.ts:86` -> maps over `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` (`planHelpers.ts:68`), finds matching Stripe price by `lookupKey`, builds `{ lookupKey, name, kind, credits, priceId: price.id, priceDollars: price.unitAmount / 100, currency, interval }` (`:93-101`)
5. `splitTiers` -- `aiSubscriptionHelpers.ts:19` -> `{ subscriptionTiers: all.filter(kind === 'subscription'), topUpTiers: all.filter(kind === 'one_off') }`
6. `topUpTiers` -- `AiCreditSubscription.tsx:51` -> `AiCreditPack` objects with `{ lookupKey, name, credits, priceDollars }`

Purchase entry:

7. `handleBuyPack(pack)` -- `AiCreditSubscription.tsx:182`
8. Branch: `currentOrganization.stripeDefaultPaymentMethodOnFile` -- `AiCreditSubscription.tsx:183`
   - true -> opens `PurchaseAiCreditTopUpConfirmModal` (`AiCreditSubscription.tsx:186`, `PurchaseAiCreditTopUpConfirmModal.tsx:15`) -> on confirm -> `removeModal()` (`AiCreditSubscription.tsx:190`) then `purchaseTopUp(pack)` (`AiCreditSubscription.tsx:191`)
   - false -> `purchaseTopUp(pack)` directly (`AiCreditSubscription.tsx:199`)
9. `purchaseTopUp` -- `AiCreditSubscription.tsx:157` -> `purchase({ stripePriceLookupKey: pack.lookupKey }, ...)` (`AiCreditSubscription.tsx:159`)
10. `purchase` -- destructured from `usePurchaseAiCreditTopUp()` (`AiCreditSubscription.tsx:45`)
11. `purchaseAiCreditTopUp` (const) -- `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts:97` -> `apiPost({ path: '/ai_credit_purchases/purchase_top_up', variables: { organizationAiCreditPurchase: params } })`
12. `usePurchaseAiCreditTopUp` (hook) -- `useOrganizationAiCreditPurchase.ts:104` -> `useMutation(purchaseAiCreditTopUp, { onSuccess: invalidate ['organizationAiCreditBalance'] })`
13. `apiPost` -- `api.ts:25` -> `allKeysToSnake({ organizationAiCreditPurchase: { stripePriceLookupKey } })` -> POST body: `{ organization_ai_credit_purchase: { stripe_price_lookup_key } }`

Frontend response handling:

14. `onSuccess` -- `AiCreditSubscription.tsx:161`
   - If `data.redirectUrl` present: `redirectToStripe({ redirectUrl: data.redirectUrl })` (`AiCreditSubscription.tsx:164`) -> `window.location.href = data.redirectUrl` (`AiCreditSubscription.tsx:61`)
   - Else (no `data.redirectUrl` -- card-on-file path returns `{ charged: true }`, but the frontend does NOT explicitly check `data.charged`; it falls through the else branch): `addToast({ title: 'Payment received -- your credits will appear shortly.', kind: 'success' })` (`AiCreditSubscription.tsx:168`)
15. `onError` -- `AiCreditSubscription.tsx:171` -> toast with `error?.data?.errors?.general?.[0] || "Top-up checkout failed"` (kind: `'warning'`, delay: 10000)

### Backend: controller action (single action, two paths)

16. route `POST /api/v1/ai_credit_purchases/purchase_top_up` -- `config/routes.rb:193`
17. `OrganizationAiCreditPurchasesController#purchase_top_up` -- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:68`
18. `authorize :billing, :checkout?` -- `controller:69` -> `BillingPolicy#checkout?` (`app/policies/billing_policy.rb:12`) -> `is_org_admin?` (`app/policies/application_policy.rb:50`)
19. `organization_ai_credit_purchase_params` -- `controller:404` -> `params.require(:organization_ai_credit_purchase).permit(:stripe_price_lookup_key, :price_id, :subscription_item_id, :return_url)`
20. `lookup_key = organization_ai_credit_purchase_params[:stripe_price_lookup_key]` -- `controller:71`
21. `OrganizationAiCreditPurchase.ai_credit_top_up_lookup_key?(lookup_key)` -- `controller:72` -> `organization_ai_credit_purchase.rb:67` -> `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY[lookup_key]&.dig(:kind) == :one_off`
22. Guard: `render_general_errors(['Invalid top-up price'])` if not valid -- `controller:73`
23. `Stripe::Price.list(lookup_keys: [lookup_key], active: true, limit: 1)` -- `controller:77` -> resolves Stripe Price for the lookup key
24. `price = prices.data.first` -- `controller:78`
25. Guard: `render_general_errors(['Price not found in Stripe for this lookup key'])` if no price -- `controller:80`
26. Pre-create purchase record:

```ruby
purchase = OrganizationAiCreditPurchase.new(
  organization: current_organization,
  kind: :one_off,
  stripe_price_lookup_key: lookup_key,
  one_off_credits_granted: OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(lookup_key),
  stripe_amount: 0,
  currency: 'usd'
)
```
-- `controller:89-96`

27. `OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key(lookup_key)` -- `organization_ai_credit_purchase.rb:71` -> `pack[:credits] || pack[:credits_per_period]`
28. `purchase.save` -- `controller:97` -> persists with `stripe_amount: 0` (placeholder), `currency: 'usd'`
29. Guard: log + `render_general_errors(['Failed to create purchase record'])` if save fails -- `controller:98-101`

### Path A: Direct Charge (payment method on file)

30. `current_organization.stripe_default_payment_method_on_file` -- `controller:103` -> boolean column `db/schema.rb:1062` (default: false), written by `sync_with_stripe` at `organization.rb:580` from `stripe_customer.invoice_settings.default_payment_method`
31. `purchase.charge_default_payment_method` -- `controller:107`

`OrganizationAiCreditPurchase#charge_default_payment_method` -- `organization_ai_credit_purchase.rb:123`:

32. Guard: `return if stripe_invoice_id.present?` -- `organization_ai_credit_purchase.rb:125` (double-charge guard)
33. Guard: `return if organization.stripe_customer_id.blank?` -- `organization_ai_credit_purchase.rb:126`
34. `Stripe::Price.list(lookup_keys: [stripe_price_lookup_key], active: true, limit: 1)` -- `organization_ai_credit_purchase.rb:128` (SECOND Stripe::Price.list call -- controller already called one at `controller:77`)
35. `price = prices.data.first` -- `organization_ai_credit_purchase.rb:129`
36. Guard: `return if price.blank?` -- `organization_ai_credit_purchase.rb:130`
37. `Stripe::InvoiceItem.create(...)` -- `organization_ai_credit_purchase.rb:132`

Stripe InvoiceItem shape verbatim (`organization_ai_credit_purchase.rb:132-141`):
```ruby
{
  customer: organization.stripe_customer_id,
  price: price.id,
  metadata: {
    organization_id: organization.id,
    organization_ai_credit_purchase_id: id,
    stripe_price_lookup_key: stripe_price_lookup_key,
    ai_credit_pack_top_up: 'true'
  }
}
```

38. `Stripe::Invoice.create(...)` -- `organization_ai_credit_purchase.rb:143`

Stripe Invoice shape verbatim (`organization_ai_credit_purchase.rb:143-153`):
```ruby
{
  customer: organization.stripe_customer_id,
  collection_method: 'charge_automatically',
  auto_advance: true,
  metadata: {
    organization_id: organization.id,
    organization_ai_credit_purchase_id: id,
    stripe_price_lookup_key: stripe_price_lookup_key,
    ai_credit_pack_top_up: 'true'
  }
}
```

39. `Stripe::Invoice.pay(invoice.id)` -- `organization_ai_credit_purchase.rb:155`
40. `update_columns(stripe_invoice_id: invoice.id, stripe_invoice_item_id: invoice_item.id, stripe_amount: paid_invoice.amount_paid, currency: paid_invoice.currency)` -- `organization_ai_credit_purchase.rb:157-162`
41. Returns `paid_invoice` -- `organization_ai_credit_purchase.rb:164`
42. Controller: `render json: { charged: true }` -- `controller:108`

### Path B: Checkout Session (no payment method on file)

43. `Stripe::Checkout::Session.create(...)` -- `controller:112`

Stripe Checkout Session shape verbatim (`controller:112-135`):
```ruby
{
  customer: current_organization.stripe_customer_id,
  mode: 'payment',
  payment_method_types: ['card'],
  line_items: [{ price: price.id, quantity: 1 }],
  invoice_creation: {
    enabled: true,
    invoice_data: {
      metadata: {
        organization_id: current_organization.id,
        organization_ai_credit_purchase_id: purchase.id,
        stripe_price_lookup_key: lookup_key,
        ai_credit_pack_top_up: 'true'
      }
    }
  },
  success_url: "#{Variables::AtsRootUrl}/hire/settings/billing?ai_credit_top_up_success=1",
  cancel_url: "#{Variables::AtsRootUrl}/hire/settings/billing?ai_credit_top_up_cancel=1",
  metadata: {
    organization_id: current_organization.id,
    organization_ai_credit_purchase_id: purchase.id,
    ai_credit_pack_top_up: 'true'
  }
}
```

44. `purchase.update(stripe_checkout_session_id: session.id)` -- `controller:137` -> stamps checkout session id on pre-created record
45. Guard: log + `render_general_errors([...])` if update fails -- `controller:138-141`
46. `render json: { redirectUrl: session.url }` -- `controller:143`
47. rescue `Stripe::StripeError` -- `controller:144` -> log + `ap e` + `Sentry.capture_exception(e, ...)` + `render_general_errors([...])` (`controller:145-148`)

### Webhook: invoice.paid (AI credit one-off branch)

Both paths converge at the `invoice.paid` webhook. The lookup uses `ai_credit_pack_top_up` metadata.

1. `handle_stripe_event` -- `stripe_webhook_handler_job.rb:44`
2. `case 'invoice.paid'` -- `stripe_webhook_handler_job.rb:198`
3. Metadata check: `object.metadata&.[]('ai_credit_pack_top_up') == 'true'` -- `stripe_webhook_handler_job.rb:212` (checked BEFORE the `board_wwr_listing_id` and `board_what_jobs_listing_id` checks)
4. Checkout session lookup for refund matching:
   - `object.payment_intent.present?` -- `stripe_webhook_handler_job.rb:216`
   - `Stripe::Checkout::Session.list(payment_intent: object.payment_intent, limit: 1)` -- `stripe_webhook_handler_job.rb:217`
   - `checkout_session_id = sessions.data.first&.id` -- `stripe_webhook_handler_job.rb:218`
5. `ApplyAiCreditPurchase.call(...)` -- `stripe_webhook_handler_job.rb:221`

ApplyAiCreditPurchase call shape verbatim (`stripe_webhook_handler_job.rb:221-229`):
```ruby
ApplyAiCreditPurchase.call(
  kind: :one_off,
  organization_id: object.metadata['organization_id'],
  amount_cents: object.amount_paid,
  currency: object.currency,
  purchase_id: object.metadata['organization_ai_credit_purchase_id'],
  checkout_session_id: checkout_session_id,
  invoice_id: object.id
)
```

6. `return` -- `stripe_webhook_handler_job.rb:230`

### Interactor: ApplyAiCreditPurchase#apply_one_off

`app/interactors/apply_ai_credit_purchase.rb:38`:

7. `organization = Organization.find(context.organization_id)` -- `apply_ai_credit_purchase.rb:39`
8. Purchase lookup (triple fallback):
   - Primary: `OrganizationAiCreditPurchase.find_by(id: context.purchase_id)` -- `apply_ai_credit_purchase.rb:46`
   - Fallback 1: `OrganizationAiCreditPurchase.find_by(stripe_checkout_session_id: context.checkout_session_id)` -- `apply_ai_credit_purchase.rb:48`
   - Fallback 2: `OrganizationAiCreditPurchase.find_by(stripe_invoice_id: context.invoice_id)` -- `apply_ai_credit_purchase.rb:50`
9. Guard: `context.fail!(error: :missing_purchase, ...)` if no record found -- `apply_ai_credit_purchase.rb:53`
10. `context.purchase = existing` -- `apply_ai_credit_purchase.rb:60`
11. Idempotency guard: `return if existing.ai_credit_balance_transactions.exists?(entry_type: :one_off_credit_pack_purchase_credit)` -- `apply_ai_credit_purchase.rb:64`
12. `balance = organization.organization_ai_credit_balance` -- `apply_ai_credit_purchase.rb:66`
13. Guard: `context.fail!(error: :missing_balance, ...)` if no balance -- `apply_ai_credit_purchase.rb:67`
14. Stripe amount backfill: `existing.update(stripe_amount: context.amount_cents, currency: ...)` if `existing.stripe_amount.to_i.zero?` -- `apply_ai_credit_purchase.rb:69-71`
15. `existing.finalize_stripe_payment` -- `apply_ai_credit_purchase.rb:73` -> `OrganizationAiCreditPurchase#finalize_stripe_payment` (`organization_ai_credit_purchase.rb:167`) -> `update_columns(stripe_invoice_paid: true)`
16. Credit ledger row:
```ruby
AiCreditBalanceTransaction.new(
  organization_ai_credit_balance: balance,
  organization_ai_credit_purchase: existing,
  entry_type: :one_off_credit_pack_purchase_credit,
  bucket: :addon,
  amount: existing.one_off_credits_granted,
  description: 'One-off credit pack purchase'
)
```
-- `apply_ai_credit_purchase.rb:75-82`
17. `ledger.save` -- `apply_ai_credit_purchase.rb:83` -> `fail_with_record_invalid(...)` if fails
18. `balance.update_columns(sent_low_notification_since_increase: false, sent_zero_notification_since_increase: false)` -- `apply_ai_credit_purchase.rb:85-88`

---

## The price model, traced both ways

### Analog (WWR): amount is hardcoded in the model

| Hop | Identifier | file:line |
|---|---|---|
| Pricing source | `calculate_charge_amount` hardcoded: standard=29900, good=36800, better=40800, best=45800 | `app/models/board_wwr_listing.rb:84-94` |
| Discount source | `wwr_percent_off` -> `organization.settings['wwr_percent_off'].to_i` | `board_wwr_listing.rb:74-77` |
| Direct-charge path | `Stripe::InvoiceItem.create(amount: amount)` -- amount in cents, no Stripe Price id | `board_wwr_listing.rb:130` |
| Checkout path | `Stripe::Checkout::Session.create(line_items: [{ price_data: { unit_amount: amount } }])` -- inline price_data, no Stripe Price id | `board_wwr_listings_controller.rb:83-91` |
| Metadata lookup key | `board_wwr_listing_id: id` (the record id, NOT a Stripe lookup_key) | `board_wwr_listing.rb:136`, `board_wwr_listings_controller.rb:106` |

The WWR analog has NO Stripe Price object. It uses hardcoded amounts and `price_data` (inline pricing). The metadata key for webhook lookup is the record's database id.

### Analog (WhatJobs): amount is hardcoded in the model

| Hop | Identifier | file:line |
|---|---|---|
| Pricing source | `calculate_charge_amount` hardcoded: 17500 ($175 flat) | `app/models/board_what_jobs_listing.rb:151-153` |
| Direct-charge path | `Stripe::InvoiceItem.create(amount: amount)` -- amount in cents, no Stripe Price id | `board_what_jobs_listing.rb:172` |
| Checkout path | `Stripe::Checkout::Session.create(line_items: [{ price_data: { unit_amount: amount } }])` -- inline price_data, no Stripe Price id | `board_what_jobs_listings_controller.rb:224-232` |
| Metadata lookup key | `board_what_jobs_listing_id: id` (record id) | `board_what_jobs_listing.rb:178`, `board_what_jobs_listings_controller.rb:247` |

### Ours: amount lives in Stripe, resolved by lookup_key

| Hop | Identifier | file:line |
|---|---|---|
| Local credit-amount source | `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` (10 keys, dev+prod) | `app/models/organization_ai_credit_purchase.rb:4-57` |
| Lookup_key -> credits | `ai_credit_allocation_for_lookup_key` -> `pack[:credits] || pack[:credits_per_period]` | `organization_ai_credit_purchase.rb:71-76` |
| Is-one-off-key check | `ai_credit_top_up_lookup_key?` -> `...dig(:kind) == :one_off` | `organization_ai_credit_purchase.rb:67-69` |
| Controller: lookup_key -> Stripe Price | `Stripe::Price.list(lookup_keys: [lookup_key], active: true, limit: 1)` -> `price.id` | `organization_ai_credit_purchases_controller.rb:77-78` |
| Model direct-charge: lookup_key -> Stripe Price (SECOND call) | `Stripe::Price.list(lookup_keys: [stripe_price_lookup_key], active: true, limit: 1)` -> `price.id` | `organization_ai_credit_purchase.rb:128-129` |
| Direct-charge: InvoiceItem uses `price:` not `amount:` | `Stripe::InvoiceItem.create(customer:, price: price.id, metadata:)` | `organization_ai_credit_purchase.rb:132` |
| Checkout: line_items uses `price:` not `price_data:` | `line_items: [{ price: price.id, quantity: 1 }]` | `organization_ai_credit_purchases_controller.rb:116` |
| Metadata lookup keys | `organization_ai_credit_purchase_id: purchase.id` + `ai_credit_pack_top_up: 'true'` + `stripe_price_lookup_key: lookup_key` | `controller:121-124`, `model:135-139` |
| Frontend credit-amount source | `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` (6 keys, all dev-prefixed -- no production `plato_ai_credit_*` keys exist in the frontend) | `app/javascript/shared/lib/planHelpers.ts:68-75` |
| Frontend catalog | `Stripe::Price.list(lookup_keys: registered_keys, active: true, expand: ['data.product'])` -> raw price list | `organization_ai_credit_purchases_controller.rb:381` |

Key difference: the analog uses hardcoded amounts with `amount:` / `price_data.unit_amount:`; ours uses Stripe Price objects with `price: price.id`. This means the dollar amount lives ONLY in Stripe for ours, and is determined at catalog-creation time, not at charge time.

---

## DB schema comparison

### board_wwr_listings (analog)

From `db/schema.rb:259-279`:

| Column | Type | Notes |
|---|---|---|
| job_id | bigint | FK to jobs |
| wwr_listing_id | string | External WWR id |
| status | integer | enum: approved/canceled/inactive |
| wwr_category | integer | enum |
| stripe_invoice_id | string | Stamped by `charge_for_listing` |
| stripe_invoice_item_id | string | Stamped by `charge_for_listing` |
| stripe_invoice_paid | boolean (default: false) | Set true by `finalize_stripe_payment` |
| stripe_amount | integer | Stamped by `charge_for_listing` |
| published_at | datetime | Set by `create_on_wwr` |
| wwr_slug | string | Set by `create_on_wwr` |
| wwr_job_listing_type | string | |
| expires_at | datetime | Set by `create_on_wwr` |
| wwr_region | string | |
| plan | integer | enum: standard/good/better/best |
| last_updated_by_organization_user_id | bigint | FK |

### board_what_jobs_listings (secondary analog)

From `db/schema.rb:217-257`:

| Column | Type | Notes |
|---|---|---|
| job_id | bigint (not null) | FK to jobs |
| stripe_invoice_id | string | Stamped by `charge_for_listing` |
| stripe_invoice_item_id | string | Stamped by `charge_for_listing` |
| stripe_invoice_paid | boolean (default: false) | Set true by `finalize_stripe_payment` |
| stripe_amount | integer | Stamped by `charge_for_listing` |
| status | integer | enum: draft/active/paused/inactive |
| (many listing-specific columns) | | |

### organization_ai_credit_purchases (ours)

From `db/schema.rb:965-989` + migration `20260611120002`:

| Column | Type | Notes |
|---|---|---|
| organization_id | bigint (not null) | FK to organizations |
| kind | integer (not null) | enum: one_off/subscription |
| stripe_subscription_id | string | Only for subscriptions |
| stripe_checkout_session_id | string | Stamped on checkout path |
| stripe_invoice_id | string | Stamped by direct-charge `update_columns` or `apply_subscription` |
| stripe_price_lookup_key | string (not null) | Set at creation |
| stripe_amount | integer | Renamed from `amount_cents_paid` by migration; stamped by `charge_default_payment_method` or `apply_one_off` |
| currency | string (default: 'usd', not null in schema / conditional in model) | |
| subscription_credits_per_period | integer | Only for subscriptions |
| one_off_credits_granted | integer | Only for one-offs |
| subscription_current_period_start | datetime | Only for subscriptions |
| subscription_current_period_end | datetime | Only for subscriptions |
| subscription_status | integer | Only for subscriptions |
| subscription_canceled_at | datetime | |
| stripe_cancel_at_period_end | boolean (default: false) | |
| refunded_at | datetime | |
| stripe_invoice_paid | boolean (default: false) | Added by migration (NOT in schema.rb yet) |
| stripe_invoice_item_id | string | Added by migration (NOT in schema.rb yet) |

---

## Data-Fetching Analog (Subscription flow, NOT WWR)

The charge/fulfillment flow follows the WWR analog. However, the product data model (how prices are fetched, displayed, and resolved) follows the **subscription analog** (`BillingController#prices` / `useBillingPrices` / `getPlansForPeriod`). This is because AI credit purchases use Stripe Products/Prices (configured in the Stripe dashboard), not locally hardcoded cent amounts like WWR.

### ANALOG — subscription data-fetching chain

1. `getPrices` (const) — `app/javascript/shared/queryHooks/useBilling.ts:102` → `apiGet({ path: '/billing/prices' })`
2. route `GET /api/v1/billing/prices` — `config/routes.rb:174`
3. `BillingController#prices` — `app/controllers/api/v1/billing_controller.rb:535` → `authorize :billing, :prices?` → `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` → `render json: price_list`
4. `useBillingPrices` (hook) — `useBilling.ts:266` → `useQuery(["billingPlans"], getPrices, { refetchOnWindowFocus })` → explicit return type `{ status, data, error, isFetching, isLoading, isSuccess, refetch }` → commented-out `window.logger("%c[useBilling] useBillingPrices", "color: #1976D2", { refetchOnWindowFocus })`
5. `getPlansForPeriod` — `app/javascript/ats/src/lib/planLookups.js:553` → matches `price.lookupKey.includes(planConfig.key)` → builds plan objects with `priceId = priceData.id` (`planLookups.js:568`)

### OURS — AI credit data-fetching chain

1. `getOrganizationAiCreditPurchasePrices` (const) — `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts:147` → `apiGet({ path: '/ai_credit_purchases/prices' })`
2. route `GET /api/v1/ai_credit_purchases/prices` — `config/routes.rb`
3. `OrganizationAiCreditPurchasesController#prices` — `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:414` → `authorize :organization_ai_credit_purchase, :show?` → `Stripe::Price.list(lookup_keys: OrganizationAiCreditPurchase.ai_credit_lookup_keys, active: true, expand: ['data.product'])` → `render json: price_list`
4. `useOrganizationAiCreditPurchasePrices` (hook) — `useOrganizationAiCreditPurchase.ts:151` → `useQuery(["organizationAiCreditPurchasePrices"], getOrganizationAiCreditPurchasePrices, { refetchOnWindowFocus })` → commented-out `window.logger`
5. `aiCreditPrices` — `app/javascript/shared/lib/planHelpers.ts:98` → matches `stripePrices.find(p => p.lookupKey === lookupKey)` → builds price objects with `priceId: price.id`, `priceDollars: price.unitAmount / 100`, `credits: AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY[lookupKey]`, `name: AI_CREDIT_PACK_DISPLAY_NAMES[lookupKey]`

### Key structural notes

- Dollar amounts come from Stripe (`price.unitAmount`), NOT from app code — no hardcoded cent values exist for AI credit purchases
- Credit counts come from app code (`AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY`) — these must stay in the codebase because Stripe does not control credit allocation
- Display names come from app code (`AI_CREDIT_PACK_DISPLAY_NAMES`) — UI convenience
- The analog fetches ALL active prices; ours filters by `lookup_keys` (the registered AI credit keys) — this is a tighter query, acceptable
- The analog expands `data.tiers`; ours expands `data.product` — different Stripe expand paths for different product structures
