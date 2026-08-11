# One-Off Purchase — Round 1 Eval

Count: 17
Previous: -1
Consecutive same: 0

[
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "Stripe Invoice.create includes `auto_advance: true` which analog omits",
    "analog": "board_wwr_listing.rb:143-151",
    "ours": "organization_ai_credit_purchase.rb:146"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "Stripe InvoiceItem.create omits `description:` that analog includes",
    "analog": "board_wwr_listing.rb:130-138",
    "ours": "organization_ai_credit_purchase.rb:132-141"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "Stripe Invoice.create omits `description:` that analog includes",
    "analog": "board_wwr_listing.rb:143-151",
    "ours": "organization_ai_credit_purchase.rb:143-153"
  },
  {
    "file": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "Checkout Session includes `payment_method_types: ['card']` which analog does not specify",
    "analog": "board_wwr_listings_controller.rb:80-118",
    "ours": "organization_ai_credit_purchases_controller.rb:115"
  },
  {
    "file": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "Checkout Session omits `payment_intent_data:` with metadata that analog includes",
    "analog": "board_wwr_listings_controller.rb:94-99",
    "ours": "organization_ai_credit_purchases_controller.rb:112-135"
  },
  {
    "file": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "Checkout Session `invoice_creation.invoice_data` omits `description:` that analog includes",
    "analog": "board_wwr_listings_controller.rb:103-104",
    "ours": "organization_ai_credit_purchases_controller.rb:119-126"
  },
  {
    "file": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "Checkout Session response shape differs -- missing `sessionId`, wrong status (200 vs 201), different key name (`redirectUrl` vs `url`)",
    "analog": "board_wwr_listings_controller.rb:120",
    "ours": "organization_ai_credit_purchases_controller.rb:143"
  },
  {
    "file": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "Direct-charge response returns minimal `{ charged: true }` flag instead of full serialized record",
    "analog": "board_wwr_listings_controller.rb:22",
    "ours": "organization_ai_credit_purchases_controller.rb:108"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "Direct-charge `update_columns` uses Stripe-reported amount (`paid_invoice.amount_paid`) instead of locally-computed amount",
    "analog": "board_wwr_listing.rb:158",
    "ours": "organization_ai_credit_purchase.rb:160"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "Direct-charge `update_columns` also stamps `currency:` which analog does not",
    "analog": "board_wwr_listing.rb:158",
    "ours": "organization_ai_credit_purchase.rb:157-162"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "Model `charge_default_payment_method` makes a redundant SECOND `Stripe::Price.list` call (controller already called it)",
    "analog": "board_wwr_listing.rb:112-164",
    "ours": "organization_ai_credit_purchase.rb:128-129"
  },
  {
    "file": "app/jobs/stripe_webhook_handler_job.rb",
    "summary": "Webhook handler makes extra `Stripe::Checkout::Session.list` API call even for direct-charge path where no checkout session exists",
    "analog": "stripe_webhook_handler_job.rb:233-243",
    "ours": "stripe_webhook_handler_job.rb:216-218"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "Double-charge guard is weaker -- checks only `stripe_invoice_id.present?` without status check",
    "analog": "board_wwr_listing.rb:115",
    "ours": "organization_ai_credit_purchase.rb:125"
  },
  {
    "file": "app/interactors/apply_ai_credit_purchase.rb",
    "summary": "No WebSocket broadcast after successful payment -- user must refresh to see credits",
    "analog": "stripe_webhook_handler_job.rb:241",
    "ours": "apply_ai_credit_purchase.rb:38-89"
  },
  {
    "file": "app/interactors/apply_ai_credit_purchase.rb",
    "summary": "No internal notification job enqueued after successful payment",
    "analog": "stripe_webhook_handler_job.rb:241",
    "ours": "apply_ai_credit_purchase.rb:38-89"
  },
  {
    "file": "app/javascript/src/helpers/planHelpers.ts",
    "summary": "Frontend/backend lookup_key mismatch -- frontend has ONLY dev-prefixed keys, no production keys; medium tier keys exist in frontend but not in backend dev keys",
    "ours": "planHelpers.ts:68-75"
  },
  {
    "file": "db/schema.rb",
    "summary": "`schema.rb` not dumped after migration 20260611120002 -- still shows old column name `amount_cents_paid` and missing `stripe_invoice_paid` and `stripe_invoice_item_id` columns",
    "ours": "db/schema.rb:972"
  }
]
