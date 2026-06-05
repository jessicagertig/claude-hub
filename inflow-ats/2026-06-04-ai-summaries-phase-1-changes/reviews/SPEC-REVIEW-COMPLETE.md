# Spec Review Complete

## Final Verdict: READY FOR PLANNING

Two consecutive full passes (Round 3 + Round 4) with zero BLOCKER or HIGH findings and zero spec amendments.

---

## Plain English Summary

This spec covers roughly 30 changes to the AI summaries and AI credits system in Inflow ATS. The changes are all local development only -- nothing here gets pushed to production yet.

The biggest structural changes are: (1) replacing two AI credit controllers with two new model-aligned controllers, renaming the associated policies and consolidating four frontend query hooks into one file; (2) fixing a Stripe webhook misrouting where credit pack top-ups were gated on the wrong event and created no invoice; (3) adding a two-step handshake for credit pack subscription checkout (mirroring how the base plan already works); and (4) consolidating three AI settings sidebar tabs into a single "Plato AI" nested container with admin-only access.

There are also bug fixes (a mailer that silently fails because `is_admin?` doesn't exist, a retry declaration that's shadowed and never fires), renames for consistency (enum field, interactor class, WebSocket action), dead code removal, and a new email notification system for bulk AI summary job completion/failure.

No new database migrations are created -- existing dev-only migrations are edited in place and re-run.

---

## Blast Radius Analysis

**Backend files touched:** ~30 (models, controllers, policies, serializers, jobs, mailers, interactors, services, initializers, rake tasks, routes, migrations)

**Frontend files touched:** ~15 (components, hooks, types, helpers, websocket handler)

**Spec files touched:** ~12 (new, renamed, updated, deleted)

**Cross-system interfaces affected:**
- Stripe webhook handler (3 event types modified: `checkout.session.completed`, `invoice.paid`, `customer.subscription.updated/deleted`)
- WebSocket GlobalChannel (2 action renames, 1 new action)
- API endpoints (2 deleted, 2 created, 1 new; response shape change on subscription read)
- React Query cache keys (1 renamed)

**Risk areas (all mitigated by spec):**
- Stripe webhook ordering: BLOCKER was found and fixed in Round 1 -- the `CustomStripeSubscriptionMissingError` guard would have blocked top-up credit pack processing
- Validation relaxation: HIGH was found and fixed -- `amount_cents_paid`/`currency` validation gap would have prevented subscription purchase creation at checkout
- Missing ripple site: HIGH was found and fixed -- `AiCreditPacks.registered_keys` reference in the model's own validation would have caused `NameError` after initializer deletion

---

## Round-by-Round Summary

### Round 1: FAIL
- **1 BLOCKER:** `invoice.paid` handler's `CustomStripeSubscriptionMissingError` guard at line 204 blocks the new `ai_credit_pack_top_up` branch for orgs without a base subscription. Fixed: branch placed before guard.
- **2 HIGH:** (a) `amount_cents_paid`/`currency` validations not relaxed for checkout-created subscription purchases. Fixed: added conditional validations. (b) Missing ripple site for `AiCreditPacks.registered_keys` in the model's own validation. Fixed: added to ripple site list.
- **4 MED:** Dead code (`apply_top_up_checkout`) -- fixed by adding removal to Note #4. TypeScript type name rename in `newLookups.ts`. Mailer arg computation location. Block parameter threading in notify_failure.
- **1 LOW:** Route naming observation (consistent with existing pattern).

### Round 2: FAIL
- **1 HIGH:** `handle_credit_pack_invoice_paid` does not populate `amount_cents_paid`/`currency` on the purchase. The `else` branch (being removed) was the only code that set these. Fixed: added fields to the `existing.update(...)` call.

### Round 3: PASS
- Zero findings. All amendments verified correct.

### Round 4: PASS
- **1 LOW:** Type file `aiCreditSubscription.ts` not mentioned in spec (implementing agent will handle naturally).
- Zero BLOCKER/HIGH. Zero amendments.

---

## Remaining Open Questions

None. All issues resolved.

---

## MED/LOW Items for Implementer Awareness

These are not spec gaps -- they're notes for the implementing agent:

1. **`newLookups.ts` type name:** When renaming enum values, also rename `AutoGenerateAiSummariesSetting` to `AutoGenerateAiSummaries` and `jobAutoGenerateAiSummariesSettingOptions` to `jobAutoGenerateAiSummariesOptions`. Update the label strings for "enabled"/"disabled".

2. **Type file rename:** `aiCreditSubscription.ts` should be renamed to match the new model name (e.g., `organizationAiCreditPurchase.ts`) and the interface renamed from `AiCreditSubscription` to `OrganizationAiCreditPurchase`.

3. **`total_queued_count` calculation:** The `notify_failure` helper on `BulkGenerateAiSummariesJob` computes `total_queued_count` from `payload['job_application_ids'].size + payload['skipped_count']` and passes it to the mailer as an argument.

4. **Block parameter threading:** `notify_failure` in `discard_on`/`retry_on` blocks accesses payload via `current_job.arguments.first` (same pattern as existing `update_remaining_statuses_to_failed`).
