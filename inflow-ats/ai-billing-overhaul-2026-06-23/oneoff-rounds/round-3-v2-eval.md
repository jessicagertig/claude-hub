# One-Off Purchase — Round 3 Eval (v2)

Count: 19
Previous: 9
Consecutive same: 0

## Findings

1. **finalize choke-point ordering** (app/jobs/stripe_webhook_handler_job.rb)
   - Analog finalizes payment before business work; ours grants credits first then finalizes (reversed)
   - Analog: stripe_webhook_handler_job.rb:239-240 (WWR), :252,:258 (WhatJobs)
   - Ours: stripe_webhook_handler_job.rb:213,:228

2. **notification + broadcast placement** (app/interactors/apply_ai_credit_purchase.rb)
   - Analog puts notification/growl/broadcast in the model method the handler calls; ours puts them in the interactor
   - Analog: board_wwr_listing.rb:193-196; stripe_webhook_handler_job.rb:256 (WhatJobs)
   - Ours: apply_ai_credit_purchase.rb:98-105

3. **webhook discriminator key** (app/jobs/stripe_webhook_handler_job.rb)
   - Analog branches on presence of record-id metadata key; ours uses a separate boolean-string flag ai_credit_pack_top_up=='true' checked before the listing branches
   - Analog: stripe_webhook_handler_job.rb:232,:245
   - Ours: stripe_webhook_handler_job.rb:212,:218

4. **record resolution in webhook path** (app/interactors/apply_ai_credit_purchase.rb)
   - Analog does a single direct find by id; ours uses a triple fallback resolver (id, checkout_session_id, invoice_id)
   - Analog: stripe_webhook_handler_job.rb:235-236,:248-249
   - Ours: apply_ai_credit_purchase.rb:46-51

5. **grant-once guard** (app/interactors/apply_ai_credit_purchase.rb)
   - Analog has no ledger/transaction existence guard (only a publish guard); ours adds an explicit ledger-existence idempotency guard
   - Analog: board_wwr_listing.rb:174; board_what_jobs_listing.rb:206
   - Ours: apply_ai_credit_purchase.rb:64

6. **charge amount source** (app/models/organization_ai_credit_purchase.rb)
   - Analog hardcodes amount in model and charges amount: cents; ours resolves a Stripe Price by lookup key and charges price: price.id
   - Analog: board_wwr_listing.rb:130-133,:84-94; board_what_jobs_listing.rb:172-175,:151-153
   - Ours: organization_ai_credit_purchase.rb:129,:139,:133

7. **duplicate Stripe::Price.list call** (app/models/organization_ai_credit_purchase.rb)
   - Analog model charge method makes no Stripe::Price call; ours issues a Stripe::Price.list duplicating the controller's call (two network calls for same price)
   - Analog: board_wwr_listing.rb:112-163
   - Ours: organization_ai_credit_purchase.rb:129; organization_ai_credit_purchases_controller.rb:84

8. **checkout line_items shape** (app/controllers/.../organization_ai_credit_purchases_controller.rb)
   - Analog uses inline price_data/unit_amount; ours uses a Stripe Price reference (price: price.id)
   - Analog: board_wwr_listings_controller.rb:83-93; board_what_jobs_listings_controller.rb:224-234
   - Ours: organization_ai_credit_purchases_controller.rb:163

9. **stamped stripe_amount value** (app/models/organization_ai_credit_purchase.rb)
   - Analog stamps the locally-computed charge amount; ours stamps price.unit_amount (Stripe Price's unit_amount), not paid_invoice.amount_paid
   - Analog: board_wwr_listing.rb:158; board_what_jobs_listing.rb:193
   - Ours: organization_ai_credit_purchase.rb:133,163

10. **InvoiceItem/Invoice metadata keys** (app/models/organization_ai_credit_purchase.rb)
    - Analog carries record-id key only; ours adds organization_id, stripe_price_lookup_key, and ai_credit_pack_top_up flag beyond the sanctioned record-id rename
    - Analog: board_wwr_listing.rb:135-137,:148-150; board_what_jobs_listing.rb:177-179,186-188
    - Ours: organization_ai_credit_purchase.rb:141-146,153-158

11. **checkout-session metadata keys** (app/controllers/.../organization_ai_credit_purchases_controller.rb)
    - Analog carries record_id/organization_id/job_id; ours adds stripe_price_lookup_key + ai_credit_pack_top_up flag (omits job_id, expected)
    - Analog: board_wwr_listings_controller.rb:94-114; board_what_jobs_listings_controller.rb:235-256
    - Ours: organization_ai_credit_purchases_controller.rb:164-189

12. **InvoiceItem currency key** (app/models/organization_ai_credit_purchase.rb)
    - Analog sets explicit currency: 'usd' on the InvoiceItem; ours omits it (currency implied by price: price.id)
    - Analog: board_wwr_listing.rb:133; board_what_jobs_listing.rb:175
    - Ours: organization_ai_credit_purchase.rb:137-147

13. **direct-charge authorization** (app/controllers/.../organization_ai_credit_purchases_controller.rb)
    - WWR primary authorizes the record (BoardWwrListingPolicy#create?); ours uses authorize :billing, :checkout? (matches WhatJobs, diverges from WWR primary), no record-level charge policy
    - Analog: board_wwr_listings_controller.rb:19; board_what_jobs_listings_controller.rb:133
    - Ours: organization_ai_credit_purchases_controller.rb:76

14. **model charge method name** (app/models/organization_ai_credit_purchase.rb)
    - Analog charge_for_listing; ours charge_for_purchase (for_listing->for_purchase record-type rename not covered by sanctioned ai_credit_* descriptor rename)
    - Analog: board_wwr_listing.rb:112; board_what_jobs_listing.rb:156
    - Ours: organization_ai_credit_purchase.rb:124

15. **charge-on-update callback** (app/models/organization_ai_credit_purchase.rb)
    - WWR primary re-charges on update (after_update :handle_after_update -> charge_for_listing unless stripe_invoice_paid); ours has no charge-triggering callback, charge fires only from explicit controller call (WhatJobs also has none)
    - Analog: board_wwr_listing.rb:9,67-72
    - Ours: organization_ai_credit_purchase.rb (no callback); organization_ai_credit_purchases_controller.rb:110

16. **pre-charge validation interactor** (app/controllers/.../organization_ai_credit_purchases_controller.rb)
    - WhatJobs runs ValidateWhatJobsListing and bails before charging; ours has no pre-charge validation interactor (validates only lookup key + Stripe price presence). WWR primary has none either
    - Analog: board_what_jobs_listings_controller.rb:156-160,207-211
    - Ours: organization_ai_credit_purchases_controller.rb:79-89,132-142

17. **toast before Stripe redirect** (app/javascript/.../AiCreditSubscription.tsx)
    - Analog checkout onSuccess redirects with no toast; ours fires addToast('Redirecting to Stripe checkout...') before redirecting
    - Analog: JobDistributionWeWorkRemotely.tsx:337-340; WhatJobsSidebarActions.tsx:133-145
    - Ours: AiCreditSubscription.tsx:193,:65-68

18. **direct-charge invalidation target** (app/javascript/.../useOrganizationAiCreditPurchase.ts)
    - Analog invalidates [jobs, data.id] / [boardWhatJobsListings, jobId]; ours invalidates [organizationAiCreditBalance] (parallel pattern, different read model, divergence forced by domain object)
    - Analog: useJob.ts:280-282 (WWR); useWhatJobsListing.ts:134-136 (WhatJobs)
    - Ours: useOrganizationAiCreditPurchase.ts:110-112

19. **WHITELIST item 1: double-charge guard 2nd predicate** (app/models/organization_ai_credit_purchase.rb)
    - Analog uses is_active?/live?; ours uses stripe_invoice_paid? (reported for completeness, not actionable)
    - Analog: board_wwr_listing.rb:115; board_what_jobs_listing.rb:160
    - Ours: organization_ai_credit_purchase.rb:126
