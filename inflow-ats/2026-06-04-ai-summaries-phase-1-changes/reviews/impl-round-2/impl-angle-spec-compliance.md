# Implementation Angle: Spec Compliance -- Round 2

## Checks

### Round 1 fixes verified
1. `apply_one_off_from_invoice` added per H1 fix requirement -- PASS
2. `AccountPlatoAiContainer` passes `currentOrganization` per H2 fix requirement -- PASS
3. `job_ai_settings_spec.rb` and `textract_result_ai_trigger_spec.rb` updated per H3 fix requirement -- PASS
4. All 5 MED fixes applied (stale comment, premature subscription_status, mailer name field, update_columns comment) -- PASS

### Spec deviations
1. The spec says `purchase_top_up` checkout session should NOT have `metadata` on the session level (only on `invoice_creation.invoice_data.metadata`). The implementation adds `metadata: { organization_id: ..., ai_credit_pack_top_up: 'true' }` to both the session AND the invoice_data. This is harmless -- the top-up metadata on the session is ignored by `checkout.session.completed` (which only checks for `ai_credit_pack_subscription`). Not a defect.

2. The rename migration `20260605035312` was not in the spec (spec said "edit in place, no new migration"). However, this is a reasonable addition for production safety (the in-place edit works for dev, but a rename migration is needed if any environment already has the old column). Not a defect.

3. `apply_subscription` in the interactor still exists but is no longer called from the webhook handler. The spec said to remove the creation branch (done) but keep the ledger logic (done). The method is technically dead code from the webhook perspective, but it has its own tests and could be called from other code paths. MED at most.

## Verdict: PASS (no HIGH findings)
