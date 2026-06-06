# spec-compliance — Round 5

## Findings

- F1 [HIGH] `app/interactors/apply_ai_credit_purchase.rb:84-130` / `apply_one_off_from_invoice` method has NO spec coverage / This 46-line method was added by a fix agent. The spec (Note #4) says the `invoice.paid` branch should "grant one-off credits using the `organization_id` and `stripe_price_lookup_key` from the invoice metadata." The spec does NOT call for a separate interactor method to do this. The spec's architecture is: webhook handler dispatches to `ApplyAiCreditPurchase.call(session: object, kind: :one_off)` -- using the session-based path. The fix agent created a parallel path that creates purchase records keyed on `stripe_invoice_id` instead of `stripe_checkout_session_id`. This also required the out-of-spec validation change on `stripe_checkout_session_id` (F2 below).

- F2 [HIGH] `app/models/organization_ai_credit_purchase.rb:53` / Validation `validates :stripe_checkout_session_id, presence: true, if: -> { one_off? && stripe_invoice_id.blank? }` is NOT in spec / The spec's validation relaxation section (Note #9B-5) covers ONLY subscription records. The one-off validation was never supposed to be relaxed. This change was introduced to support `apply_one_off_from_invoice`, which itself is out of spec.

- F3 [HIGH] `app/jobs/stripe_webhook_handler_job.rb:285-289,424-455` / `charge.refunded` handler and `handle_charge_refunded` method (31 lines) NOT in spec / The spec mentions `ApplyAiCreditRefund` only for fixing `.order` direction and removing `.reload` (Note #3). No webhook handler for refunds was specified.

- F4 [HIGH] `app/jobs/stripe_webhook_handler_job.rb:114-136` / `customer.subscription.updated` AI credit branch (22 lines) NOT in spec / No specification for handling subscription updates for credit packs.

- F5 [HIGH] `app/jobs/stripe_webhook_handler_job.rb:155-168` / `customer.subscription.deleted` AI credit branch (13 lines) NOT in spec / No specification for handling subscription deletions for credit packs.

- F6 [HIGH] `app/jobs/stripe_webhook_handler_job.rb:456-515` / `handle_credit_pack_invoice_paid` method (59 lines) NOT in spec / The spec says `handle_credit_pack_invoice_paid` should be modified (add `amount_cents_paid` and `currency`, remove `else` branch). Instead, the implementation wrote this method from scratch with additional logic including idempotency checks (`already_processed` query), transaction wrapping, `Stripe::Subscription.retrieve`, and detailed error logging -- none of which were specified.

- F7 [HIGH] `app/jobs/stripe_webhook_handler_job.rb:517-527` / `subscription_status_for_stripe` helper method NOT in spec / New mapping function for Stripe status strings to enum symbols. Not specified.

- F8 [MED] `db/migrate/20260605035312_rename_auto_generate_ai_summaries_setting_to_auto_generate_ai_summaries.rb` / New migration created despite spec saying "No new database migrations are created" / The spec says to edit migration `20260408040701` in place.

- F9 [MED] `app/jobs/stripe_webhook_handler_job.rb:270-284` / Three-tier rescue in `invoice.paid` NOT in spec / Original had single `rescue StandardError`. Fix agent restructured to `Stripe::StripeError` / `ActiveRecord::RecordInvalid|RecordNotFound` / `StandardError` with re-raise. The re-raise changes retry behavior.

- F10 [MED] `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:52` / `amount_cents_paid: 0` not in spec / Spec says to create purchase with `kind: :subscription`, `stripe_checkout_session_id`, `stripe_price_lookup_key`, and `subscription_credits_per_period` at checkout. Does not specify `amount_cents_paid: 0`.

**Summary of out-of-spec code:** The fix agent added approximately 200+ lines of new webhook handler code (charge.refunded, subscription.updated AI branch, subscription.deleted AI branch, handle_credit_pack_invoice_paid, subscription_status_for_stripe), a 46-line interactor method, a validation change, and a new migration -- none of which appeared in the spec.
