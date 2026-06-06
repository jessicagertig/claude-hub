# reinventing-the-wheel — Round 5

## Findings

- F1 [HIGH] `app/interactors/apply_ai_credit_purchase.rb:84-130` vs existing listing pattern / `apply_one_off_from_invoice` reinvents what the listing branches do inline / The user's exact concern: "We do plenty of one-off purchases for WWR listing and What Jobs board listing without needing all that."

  **How listings handle one-off `invoice.paid`** (develop branch, `stripe_webhook_handler_job.rb:199-229`):
  1. Check metadata: `object.metadata&.[]('board_wwr_listing_id').present?`
  2. Look up the record: `listing = BoardWwrListing.find(listing_id)`
  3. Process inline: `listing.finalize_stripe_payment` / `listing.create_on_wwr`
  4. Return to prevent fall-through

  Total: 8-12 lines of inline code per listing type. No interactor. No separate method. No purchase record creation in the webhook handler.

  **How `apply_one_off_from_invoice` handles one-off `invoice.paid`:**
  1. Look up org from metadata
  2. Check for existing purchase (idempotency)
  3. Look up balance
  4. Extract lookup_key from metadata
  5. Look up credits from registry
  6. Create `OrganizationAiCreditPurchase` record
  7. Create `AiCreditBalanceTransaction` ledger row
  8. Reset notification flags

  Total: 46 lines in a dedicated interactor method.

  The credit pack top-up DOES need to create a purchase record and ledger row (listings don't have this), so the work IS more than a listing. But this work is already done by `apply_one_off(session)` -- the ONLY difference is the data source (invoice metadata vs checkout session). The fix agent duplicated the entire method rather than parameterizing the data source.

  **Recommended approach:** Extract the org-lookup / credit-grant / ledger-write logic into a shared path. Pass in `{ organization:, lookup_key:, amount:, currency:, unique_key: }` and let the caller (webhook handler or interactor) determine where those values come from. This eliminates the 46-line duplication.

- F2 [MED] `app/jobs/stripe_webhook_handler_job.rb:456-515` / `handle_credit_pack_invoice_paid` reinvents `ApplyAiCreditPurchase.apply_subscription` / The `handle_credit_pack_invoice_paid` method does subscription renewal credit granting with a transaction, ledger row creation, and notification flag reset. `apply_subscription` in `ApplyAiCreditPurchase` does the same thing for first-invoice credit granting. These two code paths share the same logic (find purchase, create ledger row, reset flags) but are implemented separately with different error handling, different idempotency strategies, and different transaction boundaries. The spec intended `handle_credit_pack_invoice_paid` to call `ApplyAiCreditPurchase`, not to duplicate its internals.
