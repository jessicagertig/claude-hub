# One-Off Purchase — Round 2 Fixes (v3)

The situation is now definitively confirmed and unrecoverable by me without overstepping. Let me do one final check to be certain this is an external revert and not something I can simply re-apply — specifically, whether my controller edits could even be re-applied (they can't, because the controller is now a different file structure entirely — single `purchase_top_up` action vs the two split actions my edits targeted). And let me verify whether the model/controller revert happened to HEAD content that predates the entire two-action feature.

The evidence is complete. I'll stop here and report. Re-applying my four edits is impossible because:

1. **Finding 1** (already-fixed `charge_for_purchase` no-arg): the method `charge_for_purchase` **no longer exists** on the model. The reverted controller's `purchase_top_up` doesn't charge a card at all — it only creates a Checkout Session. The entire direct-charge model-method design is gone.
2. **Finding 3** (remove `stripe_invoice_paid: false` from `charge_top_up`): the action `charge_top_up` **no longer exists**. There is no direct-charge build block to edit.
3. **Finding 4** (split param methods + flat frontend payload): the `create_top_up_checkout_session` action **no longer exists**; the controller has a single `organization_ai_credit_purchase_params` and a single `purchase_top_up`. My `checkout_top_up_params` and the frontend flat-payload edit now point at a backend that doesn't exist.

The working tree is internally broken independent of my work (routes → missing controller actions; specs → missing model methods; frontend → missing endpoints), so even reverting my own edits would not produce a green tree.

I'm stopping rather than (a) reconstructing the entire two-action analog-matching feature from scratch (far beyond "fix deviations to match the analog" — the feature itself was removed), or (b) rewriting 39 failing specs to match the reverted code (forbidden by the hard rule against rewriting tests to pass, and against the analog-matching goal).

---

## SUMMARY

**CRITICAL: The working tree was reverted out from under me mid-task and is now internally inconsistent. I could not complete the fixes.**

When I started, the working tree already contained an in-progress "two-action" analog-matching implementation (separate `charge_top_up` + `create_top_up_checkout_session` controller actions, a `charge_for_purchase` model method, and lookup-key methods `ai_credit_top_up_lookup_key?` etc.). Findings 1 and 2's fixes and most spec updates were already present. I made the remaining edits:

1. **Finding 3 (FIXED, then lost):** Removed `stripe_invoice_paid: false` from the `charge_top_up` build block in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (schema default is `false`, so behavior-preserving), matching WWR `#create` which only relies on the schema default while `#create_checkout_session` sets it explicitly.
2. **Finding 4 (FIXED, then lost):** Split the param method — added `checkout_top_up_params` (`params.permit(:stripe_price_lookup_key)`, no wrapper) used by `create_top_up_checkout_session`, kept `organization_ai_credit_purchase_params` (wrapper) for `charge_top_up`; and changed the frontend `createAiCreditTopUpCheckoutSession` in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts` to send a flat `{ stripePriceLookupKey }` payload; and updated the controller spec helper `post_create_checkout_session` to post flat params. These mirror WWR's `listing_params` (wrapper, direct path) vs `checkout_listing_params` (no wrapper, checkout path) split. **These two specs passed: 27 examples, 0 failures.**

**Then an external process reverted `app/models/organization_ai_credit_purchase.rb` and `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` all the way back to HEAD (commit `9e3302f25`)** — an OLDER single-action design. After the revert:
- The model NO LONGER defines `charge_for_purchase`, `charge_default_payment_method`, `ai_credit_top_up_lookup_key?`, `ai_credit_subscription_plan_lookup_key?`, `ai_credit_allocation_for_lookup_key`, or `ai_credit_lookup_keys`. It instead has `registered_keys`, `subscription_key?`, `one_off_key?`, `credit_amount_for_key`, and uses the pre-rename `amount_cents_paid`.
- The controller NO LONGER has `charge_top_up` or `create_top_up_checkout_session`; it has a single `purchase_top_up` (checkout-session only, no direct card charge) and a single `organization_ai_credit_purchase_params` permitting only `:stripe_price_lookup_key`. My controller edits are gone.
- `config/routes.rb` (still `MM`) routes `POST charge_top_up` and `POST create_top_up_checkout_session` to controller actions **that no longer exist**.
- The frontend hook (still `MM`) and specs (`organization_ai_credit_purchase_spec.rb`, `apply_ai_credit_purchase_spec.rb`, `stripe_webhook_handler_ai_credits_spec.rb`, all `MM`) still target the two-action / `charge_for_purchase` design that was removed.

**Result:** Running the one-off suite now yields ~39 failures (`spec/interactors/apply_ai_credit_purchase_spec.rb`, `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`, `spec/models/organization_ai_credit_purchase_spec.rb`) because the specs reference model methods (`charge_for_purchase`, `ai_credit_top_up_lookup_key?`) and the reverted model has different method names. **These failures are NOT caused by my edits** — they are caused by the model/controller being reverted to an earlier revision while routes/specs/frontend were left on the newer design.

**Why I stopped instead of continuing:** The four findings target a two-action analog-matching implementation that has been entirely removed from the model and controller. I cannot "fix the deviations to match the analog" because the code containing those deviations no longer exists. Re-applying my edits is impossible (the actions/methods they edit are gone). The only ways forward would be (a) reconstructing the whole two-action feature from scratch — far outside "fix deviations" scope and likely to be reverted again, or (b) rewriting 39 failing specs to match the reverted code — which violates the hard rule against rewriting tests to pass. Neither is appropriate without your direction.

**WHITELIST items:**
- **Finding 2 (double-charge guard second condition):** The analog guards `stripe_invoice_id.present? && is_active?` (WWR) / `&& live?` (WhatJobs), where `is_active?`/`live?` are `expires_at`-based listing-lifecycle predicates (`<expires_at>.present? && <expires_at> > now && <terminal_status>?`). `OrganizationAiCreditPurchase` has no `expires_at` column and no publish/listing lifecycle, so the literal predicate cannot exist on our record type. The implementation used `stripe_invoice_paid?` — the structural stand-in for "this purchase has reached its terminal done-state" — which is the correct analog. (Now moot: the reverted model has neither `charge_for_purchase` nor this guard.)

**What needs your decision:** The billing-bonanza working tree needs to be reconciled to a single consistent revision before any analog-matching work can proceed. Either the model + controller need to be restored to the two-action / `charge_for_purchase` design (matching the still-present routes, frontend hooks, and specs), or routes + frontend + specs need to be reverted to the single-`purchase_top_up` design. I did not modify or restore anything further, to avoid making the inconsistent state worse or destroying work. No git branches were created/deleted; no database commands were run.
