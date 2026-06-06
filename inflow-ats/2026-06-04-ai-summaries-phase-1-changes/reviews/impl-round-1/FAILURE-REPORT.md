# FAILURE REPORT -- Implementation Review Round 1

**Date:** 2026-06-04
**Verdict:** FAIL (4 HIGH findings, 3 unique defects)

---

## Defect 1 (HIGH): `invoice.paid` top-up handler passes invoice as checkout session

**Files:** `app/jobs/stripe_webhook_handler_job.rb:212`, `app/interactors/apply_ai_credit_purchase.rb:41`

**Problem:** The `invoice.paid` handler for AI credit top-ups calls:
```ruby
ApplyAiCreditPurchase.call(session: object, kind: :one_off)
```
where `object` is the Stripe invoice (from the `invoice.paid` event). Inside `ApplyAiCreditPurchase#apply_one_off`, line 41 calls:
```ruby
Stripe::Checkout::Session.list_line_items(session.id, limit: 1)
```
This API only accepts checkout session IDs (`cs_xxx`), not invoice IDs (`in_xxx`). In production, this will raise `Stripe::InvalidRequestError` and the top-up credits will never be granted -- the customer pays but receives nothing.

**Why the test misses it:** The spec stubs `Stripe::Checkout::Session.list_line_items` to accept an invoice ID (`in_test_topup`), masking the type mismatch.

**Fix:** The `invoice.paid` handler already has the lookup key in the invoice metadata (`object.metadata['stripe_price_lookup_key']`). Two options:

**Option A (minimal):** In the `invoice.paid` handler, build the one-off purchase directly instead of delegating to `ApplyAiCreditPurchase`:
```ruby
if object.metadata&.[]('ai_credit_pack_top_up') == 'true'
  lookup_key = object.metadata['stripe_price_lookup_key']
  org = Organization.find_by(id: object.metadata['organization_id'])
  if org && lookup_key
    credits = OrganizationAiCreditPurchase.credit_amount_for_key(lookup_key)
    # Create purchase and grant credits directly, similar to apply_one_off
    # but using invoice fields instead of checkout session fields
  end
end
```

**Option B (preferred, less duplication):** Add a separate method to `ApplyAiCreditPurchase` (e.g., `apply_one_off_from_invoice`) that accepts an invoice and extracts the lookup key from metadata instead of calling `list_line_items`. Or modify `apply_one_off` to accept either a session or invoice by checking `context.session` vs `context.invoice`.

**Spec fix:** Update the invoice.paid top-up spec to NOT stub `Stripe::Checkout::Session.list_line_items` with an invoice ID. The spec should test the actual code path, not mask a type mismatch.

---

## Defect 2 (HIGH): `AccountPlatoAiContainer` missing `currentOrganization` prop

**Files:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AccountPlatoAiContainer.tsx:48-53`, `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx:207`

**Problem:** `OrganizationAiSettings` destructures `currentOrganization` from props (line 17) and immediately accesses `currentOrganization.settings` (line 18). Previously, `AccountContainer` passed `currentOrganization={currentOrganization}` explicitly. After the refactor:
1. `AccountContainer` renders `<AccountPlatoAiContainer {...props} {...renderProps} />`
2. `AccountPlatoAiContainer` passes `{...props} {...renderProps} setIsDirty={setIsDirty}` to `OrganizationAiSettings`
3. But `currentOrganization` comes from `useCurrentSession()` inside `AccountContainer`, NOT from `props`
4. `currentOrganization` is `undefined` in `OrganizationAiSettings`
5. Crash: `TypeError: Cannot read properties of undefined (reading 'settings')`

**Fix:** In `AccountPlatoAiContainer`, import and call `useCurrentSession()` to get `currentOrganization`, then pass it explicitly:
```tsx
import { useCurrentSession } from "@ats/src/context/CurrentSessionContext";

function AccountPlatoAiContainer(props) {
  const { match } = props;
  const { currentOrganization } = useCurrentSession();
  // ...
  <OrganizationAiSettings
    {...props}
    {...renderProps}
    setIsDirty={setIsDirty}
    currentOrganization={currentOrganization}
  />
}
```

---

## Defect 3 (HIGH): Stale enum/method references in two existing spec files

**Files:**
- `spec/models/job_ai_settings_spec.rb` (4 stale enum refs + 5 stale method calls)
- `spec/models/textract_result_ai_trigger_spec.rb` (9 stale enum/settings refs)

**Problem:** These spec files reference the old enum name (`auto_generate_ai_summaries_setting`), old values (`:inherit`, `:on`, `:off`), old method name (`effective_auto_generate_ai_summaries_enabled?`), and old settings key (`default_auto_generate_ai_summaries_enabled`). After the rename, these specs will fail with `ArgumentError: 'inherit' is not a valid auto_generate_ai_summaries`.

**Note:** These files were not listed in the plan's "Files to Modify" table, so this is a plan omission that propagated to the implementation. The implementation correctly followed the plan; the plan was incomplete.

**Fix:** Update both files:

**`spec/models/job_ai_settings_spec.rb`:**
- `auto_generate_ai_summaries_setting:` to `auto_generate_ai_summaries:`
- `:inherit` to `:default`
- `:on` to `:enabled`
- `:off` to `:disabled`
- `#effective_auto_generate_ai_summaries_enabled?` to `#should_auto_generate_ai_summaries?`
- `effective_auto_generate_ai_summaries_enabled?` calls to `should_auto_generate_ai_summaries?`

**`spec/models/textract_result_ai_trigger_spec.rb`:**
- `default_auto_generate_ai_summaries_enabled:` to `auto_generate_ai_summaries_enabled:`
- `auto_generate_ai_summaries_setting:` to `auto_generate_ai_summaries:`
- `:inherit` to `:default`
- `:on` to `:enabled`
- `:off` to `:disabled`

---

## MED findings (do not block, but should be addressed)

1. `app/interactors/reset_ai_credits.rb:6` -- stale comment references `process_overdue_ai_credit_resets`
2. `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:52` -- sets `subscription_status: :active` at checkout instead of nil per spec
3. `app/mailers/bulk_job_application_ai_summary_result_mailer.rb:12,36` -- missing `name:` in `to:` field (analog includes it)
4. `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb` -- stubs `list_line_items` with invoice ID, masking Defect 1
5. `app/jobs/stripe_webhook_handler_job.rb:61` -- uses `update_columns` without comment explaining why
