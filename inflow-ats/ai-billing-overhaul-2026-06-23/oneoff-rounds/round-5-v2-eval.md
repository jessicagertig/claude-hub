# One-Off Purchase — Round 5 Eval (v2)

Count: 2
Previous: 6
Consecutive same: 0

[
  {
    "file": "/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "Direct-charge path (#charge_top_up) discards AR validation errors on save failure and renders a fixed generic string instead of the record's field-level errors",
    "analog": "board_wwr_listings_controller.rb:21,24-25 (render_errors(@listing) in #create)",
    "ours": "organization_ai_credit_purchases_controller.rb:101-104 (render_general_errors(['Failed to create purchase record']) in #charge_top_up)"
  },
  {
    "file": "/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb",
    "summary": "Checkout-session path (#create_top_up_checkout_session) discards AR validation errors on save failure and renders a fixed generic string instead of the record's field-level errors",
    "analog": "board_wwr_listings_controller.rb:76,121-122 (render_errors(@listing) in #create_checkout_session)",
    "ours": "organization_ai_credit_purchases_controller.rb:156-159 (render_general_errors(['Failed to create purchase record']) in #create_top_up_checkout_session)"
  }
]
