# One-Off Purchase — Round 2 Eval

Count: 17
Previous: 17
Consecutive same: 0

[
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "charge_default_payment_method takes a price argument from controller instead of resolving price internally like analog's zero-arg charge_for_listing; trace row 34 wrongly claims model makes its own Stripe::Price.list call",
    "analog": "app/models/board_wwr_listing.rb:112",
    "ours": "app/models/organization_ai_credit_purchase.rb:123"
  },
  {
    "file": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "Direct-charge response is render_one(purchase, Serializer) matching analog pattern; trace row 42 wrongly claims response is render json: { charged: true }",
    "analog": "app/controllers/api/v1/board_wwr_listings_controller.rb:23",
    "ours": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:108"
  },
  {
    "file": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "Checkout response now includes sessionId and status: :created matching analog; trace row 46 wrongly claims neither is present",
    "analog": "app/controllers/api/v1/board_wwr_listings_controller.rb:120",
    "ours": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:150"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "InvoiceItem.create includes description field in actual code; trace structural table wrongly says description is MISSING in ours",
    "analog": "app/models/board_wwr_listing.rb:130-138",
    "ours": "app/models/organization_ai_credit_purchase.rb:131-141"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "Invoice.create includes description field in actual code; trace structural table wrongly says description is MISSING in ours",
    "analog": "app/models/board_wwr_listing.rb:143-151",
    "ours": "app/models/organization_ai_credit_purchase.rb:143-153"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "Invoice.create does NOT include auto_advance: true in actual code; trace structural table wrongly says auto_advance is EXTRA in ours",
    "analog": "app/models/board_wwr_listing.rb:143-151",
    "ours": "app/models/organization_ai_credit_purchase.rb:143-153"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "update_columns uses price.unit_amount (pre-charge Stripe Price amount) not paid_invoice.amount_paid (post-charge); trace row 40 wrongly documents Stripe response amount and extra currency field",
    "analog": "app/models/board_wwr_listing.rb:158",
    "ours": "app/models/organization_ai_credit_purchase.rb:157"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "update_columns does NOT write currency field in actual code; trace row 40 wrongly claims currency: paid_invoice.currency is written",
    "analog": "app/models/board_wwr_listing.rb:158",
    "ours": "app/models/organization_ai_credit_purchase.rb:157"
  },
  {
    "file": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "purchase_top_up checkout session does NOT include payment_method_types: ['card'] in actual code; trace row 43 wrongly says it is EXTRA in ours",
    "analog": "app/controllers/api/v1/board_wwr_listings_controller.rb:80-118",
    "ours": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:112-142"
  },
  {
    "file": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "Checkout session INCLUDES payment_intent_data with metadata in actual code; trace structural table wrongly says payment_intent_data is MISSING in ours",
    "analog": "app/controllers/api/v1/board_wwr_listings_controller.rb:95-101",
    "ours": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:116-122"
  },
  {
    "file": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "Checkout session invoice_data INCLUDES description: 'AI Credit Top-Up' in actual code; trace structural table wrongly says ours omits description",
    "analog": "app/controllers/api/v1/board_wwr_listings_controller.rb:103-109",
    "ours": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:126"
  },
  {
    "file": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "stripe_price_lookup_key is in payment_intent_data.metadata and invoice_data.metadata but NOT in top-level metadata; trace does not distinguish which metadata block contains the key",
    "analog": "",
    "ours": "app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:135-139"
  },
  {
    "file": "app/jobs/stripe_webhook_handler_job.rb",
    "summary": "Webhook does NOT perform Stripe::Checkout::Session.list call in actual code; trace rows 4-5 wrongly claim checkout session lookup exists as EXTRA",
    "analog": "",
    "ours": "app/jobs/stripe_webhook_handler_job.rb:212-221"
  },
  {
    "file": "app/jobs/stripe_webhook_handler_job.rb",
    "summary": "ApplyAiCreditPurchase.call passes invoice_id but NOT checkout_session_id in actual code; trace row 5 wrongly claims checkout_session_id is passed",
    "analog": "",
    "ours": "app/jobs/stripe_webhook_handler_job.rb:213-220"
  },
  {
    "file": "app/jobs/notification/paid_ai_credit_pack_purchased_job.rb",
    "summary": "Bug: rescue ActiveRecord::RecordNotFound without => e but line 14 references ap e -- will raise NameError at runtime masking original error",
    "analog": "app/jobs/notification/paid_wwr_listing_created_job.rb",
    "ours": "app/jobs/notification/paid_ai_credit_pack_purchased_job.rb:12-14"
  },
  {
    "file": "app/interactors/apply_ai_credit_purchase.rb",
    "summary": "Broadcast and notification job EXIST in actual code (GlobalChannel.broadcast_to + Notification::PaidAiCreditPackPurchasedJob); trace structural table wrongly says both are MISSING",
    "analog": "app/models/board_wwr_listing.rb:173",
    "ours": "app/interactors/apply_ai_credit_purchase.rb:94-101"
  },
  {
    "file": "app/models/organization_ai_credit_purchase.rb",
    "summary": "Double-charge guard is two conditions (stripe_invoice_id.present? && stripe_invoice_paid?) not single-condition as trace claims; closer to analog's two-condition guard but second condition differs",
    "analog": "app/models/board_wwr_listing.rb:115",
    "ours": "app/models/organization_ai_credit_purchase.rb:126"
  }
]
