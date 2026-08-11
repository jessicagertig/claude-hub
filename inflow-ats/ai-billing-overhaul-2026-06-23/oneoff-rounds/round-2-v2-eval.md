# One-Off Purchase — Round 2 Eval (v2)

Count: 9
Previous: 4
Consecutive same: 0

[
  {
    "file": "organization_ai_credit_purchase.rb",
    "summary": "Direct-charge model method named charge_default_payment_method instead of analog's charge_for_<record> verb (charge_for_listing)",
    "analog": "board_wwr_listing.rb:112",
    "ours": "organization_ai_credit_purchase.rb:124"
  },
  {
    "file": "organization_ai_credit_purchases_controller.rb",
    "summary": "Direct-charge action rescues only Stripe::StripeError; no StandardError rescue, so non-Stripe errors in charge escape unhandled unlike analog",
    "analog": "board_wwr_listings_controller.rb:28-31",
    "ours": "organization_ai_credit_purchases_controller.rb:154-158"
  },
  {
    "file": "organization_ai_credit_purchases_controller.rb",
    "summary": "Extra post-session update write (purchase.update stripe_checkout_session_id) that the analog never performs; analog relies solely on metadata",
    "analog": "board_wwr_listings_controller.rb:76-118",
    "ours": "organization_ai_credit_purchases_controller.rb:147"
  },
  {
    "file": "organization_ai_credit_purchases_controller.rb",
    "summary": "stripe_invoice_paid not set in checkout-path build params (relies on column default); analog passes stripe_invoice_paid: false explicitly",
    "analog": "board_wwr_listings_controller.rb:62",
    "ours": "organization_ai_credit_purchases_controller.rb:89-97"
  },
  {
    "file": "organization_ai_credit_purchases_controller.rb",
    "summary": "success_url/cancel_url carry only a static flag and no session id; analog embeds &session_id={CHECKOUT_SESSION_ID}",
    "analog": "board_wwr_listings_controller.rb:116-117",
    "ours": "organization_ai_credit_purchases_controller.rb:143-144"
  },
  {
    "file": "stripe_webhook_handler_job.rb",
    "summary": "invoice.paid branch delegates to ApplyAiCreditPurchase so finalize_stripe_payment runs in the interactor, not in-handler like the analog choke point",
    "analog": "stripe_webhook_handler_job.rb:231-232",
    "ours": "stripe_webhook_handler_job.rb:213-220"
  },
  {
    "file": "useOrganizationAiCreditPurchase.ts",
    "summary": "Frontend always calls one endpoint (purchase_top_up) with controller branching internally; analog frontend splits card-vs-no-card across two endpoints",
    "analog": "useWwrListing.ts:7-24",
    "ours": "useOrganizationAiCreditPurchase.ts:97-102"
  },
  {
    "file": "AiCreditSubscription.tsx",
    "summary": "purchaseTopUp onSuccess branches on data.url/data.charged response fields; analog's direct-charge handler inspects no response fields, only clears form state",
    "analog": "JobDistributionWeWorkRemotely.tsx:269-272",
    "ours": "AiCreditSubscription.tsx:161-165"
  },
  {
    "file": "AiCreditPackCard.tsx",
    "summary": "Buy button passes only loading prop, no disabled; analog passes both loading and disabled so button is not disabled during in-flight purchase",
    "analog": "JobDistributionWeWorkRemotely.tsx:477-481",
    "ours": "AiCreditPackCard.tsx:36"
  }
]
