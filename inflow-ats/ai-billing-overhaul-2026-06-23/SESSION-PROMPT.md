You are picking up an AI credit billing analog-matching project for inflow-ats.

## What we're doing

Making AI credit billing code structurally match its analogs — like a junior engineer copy-pasted the analog code and edited as little as possible. Four flows need audit/fix loops, one at a time:

1. One-off purchase (analog: WWR `BoardWwrListing` / WhatJobs `BoardWhatJobsListing`) — note that the WWR analog has two controller actions in the same controller (`#create` for direct charge, `#create_checkout_session` for no-card), not a major architectural split
2. Subscription renewal (analog: main subscription `invoice.paid` handler)
3. `customer.subscription.updated` (analog: main-plan branch in same handler)
4. `customer.subscription.deleted` (analog: main-plan branch in same handler)

## Locations

- **Source repo worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`
- **Scratchpad:** `~/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/`
- **Structural traces (the specification):** `~/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/traces/`
  - `oneoff-purchase-trace.md` — one-off purchase vs WWR (includes data-fetching analog section referencing subscription pattern)
  - `subscription-renewal-trace.md`
  - `subscription-updated-trace.md`
  - `subscription-deleted-trace.md`
- **Sanctioned deviations (READ-ONLY for agents):** `~/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/SANCTIONED-DEVIATIONS.md`
- **Follow-up items (not blocking):** `~/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/FOLLOW-UP-ITEMS.md`
- **Prior session's working audit loop (read for format/approach):** `~/claude-hub/inflow-ats/_in-progress/ai-credit-change-flow-audit-fix-loop.md`
- **Prior session's gold-standard trace:** `~/claude-hub/inflow-ats/_in-progress/ai-credit-subscription-change-analog-trace.md`
- **Prior session's manifests:** `~/claude-hub/inflow-ats/_in-progress/ai-credit-change-and-topup-analog-manifest.md`

## About the traces

Each trace maps BOTH sides — the Analog chain and the Ours chain. The Analog sections are the specification: what the code must look like. The Ours sections describe what our code looked like when the trace was built — they provide context for the original state but may be stale after fixes. The Analog sections are the source of truth for what to match against.

## Current state of the code

The stash from `ai-feature-work-v5` is applied to `billing-bonanza`. Migration files exist:
- `20260611120002` — adds `stripe_invoice_paid` (boolean, default false), `stripe_invoice_item_id` (string), renames `amount_cents_paid` → `stripe_amount`
- `20260611120003` — adds `last_updated_by_organization_user_id`

Migrations are NOT run. The app code still references old column names (`amount_cents_paid`). Implementation changes need to happen FIRST.

## Step 0: Implementation (before any audit)

These changes are agreed upon and should be applied without discussion:

1. Rename `amount_cents_paid` → `stripe_amount` across all layers: model (`organization_ai_credit_purchase.rb`), controller (`organization_ai_credit_purchases_controller.rb`), interactor (`apply_ai_credit_purchase.rb`), webhook handler (`stripe_webhook_handler_job.rb`), serializer (`organization_ai_credit_purchase_serializer.rb`), frontend TS type (`organizationAiCreditPurchase.ts`: `amountCentsPaid` → `stripeAmount`), all frontend components referencing it
2. Add `finalize_stripe_payment` to `OrganizationAiCreditPurchase` — read `BoardWwrListing#finalize_stripe_payment` and `BoardWhatJobsListing#finalize_stripe_payment` and copy exactly
3. Wire `finalize_stripe_payment` into the `invoice.paid` webhook handler BEFORE credit granting — mirror how WWR calls `listing.finalize_stripe_payment` then `listing.create_on_wwr`
4. Stamp `stripe_invoice_item_id` in the charge method — read how WWR stamps it in `charge_for_listing`
5. After all implementation changes: `git add -A` to stage everything. From this point, audit/fix changes will be unstaged.

## Step 1: Audit/fix loop — one flow at a time

### How to run the loop

Launch a workflow with NO auto-stop, NO convergence logic, NO caps. It runs endlessly until you stop it externally. Do NOT use Haiku for any agents in the workflow — use Opus 4.8 for all agents including log writers.

```
while true:
  read whitelist ONLY from SANCTIONED-DEVIATIONS.md (never from any other file)
  audit agent (Opus 4.8): read ANALOG sections of the trace, read current code, report deviations
  write audit log to <flow>-rounds/round-N-audit.md
  fix agent (Opus 4.8): fix every deviation to match the analog
  write fix log to <flow>-rounds/round-N-fixes.md
```

Check on it every 5 minutes. Read the round logs yourself. When converged (0 deviations for 2+ rounds, or a small set of genuinely unavoidable items oscillating), stop it and bring the remaining items to Jessica.

### Items a prior audit flagged for the one-off purchase flow

A previous audit/fix run identified these areas as deviations. This is NOT an exhaustive list and NOT instructions — just things the audit should definitely check on:

- Whether the controller has separate actions for direct charge vs checkout session
- Authorization pattern — object-level vs action-level
- Metadata key count on InvoiceItem, Invoice, and checkout session
- How the direct-charge method gets the dollar amount
- How the webhook handler routes and finds the purchase record
- Whether the interactor has a fallback lookup chain
- Where broadcast/notification logic lives (model method vs interactor)
- Frontend response keys and how onSuccess handlers use them
- Param methods — one shared vs separate per action
- Whether `stripe_invoice_paid` is set explicitly or relies on schema default
- Whether `last_updated_by_organization_user` is associated, stamped, and used for growl targeting
- Spec references to renamed columns

### Critical rules for audit agents

- The Analog sections of the trace are the specification. Compare CURRENT code against the analog.
- Report EVERY deviation: `DEVIATION: [aspect] | ANALOG: [file:line what it does] | OURS: [file:line what it does]`
- Do NOT classify deviations as minor/forced/appropriate.
- Do NOT flag items from SANCTIONED-DEVIATIONS.md.

### Critical rules for fix agents

- Read the ANALOG code first, then make OURS match. Copy-paste, edit minimally.
- Fix BOTH backend AND frontend together. No "coordinated change" excuses. If the backend response key changes, change the frontend that reads it.
- If something cannot be matched exactly, attempt a fix as close as possible and report it as `CANNOT-MATCH: [item]: [reason]` in the fix log. Add the item to `SUGGESTED-WHITELISTS.md` with your reasoning. NEVER write to `SANCTIONED-DEVIATIONS.md` — only Jessica adds to that file.
- NEVER whitelist because something is hard or requires refactoring. Amount of work is irrelevant. Match the analog.

### Reverting code

Never revert code unless Jessica explicitly tells you to. She will say "revert the unstaged code" or "revert file X." No other instruction qualifies as a reason to revert code.

### Grant-once guard (sanctioned decision)

The grant-once guard must use this exact pattern:
```ruby
existing_grant = organization_ai_credit_purchase.ai_credit_balance_transactions.find_by(
  entry_type: :one_off_credit_pack_purchase_credit
)
return if existing_grant && existing_grant.amount.positive?
```
This is a sanctioned decision documented in `SANCTIONED-DEVIATIONS.md`. Do not change it.

### Variable naming rule

Name every variable so it can be immediately matched to its model. `existing`, `record`, `item`, `purchase`, `transaction`, `txn`, `ledger`, `latest` are NEVER acceptable for database-backed records. Use the full model name: `organization_ai_credit_purchase`, `ai_credit_balance_transaction`. See CLAUDE.md rule 18.

### Model override for Opus 4.8

Use `model: 'claude-opus-4-8'` in all workflow agent calls. `model: 'opus'` resolves to 4.6. Do NOT use Haiku for any workflow agents.

### After one-off flow converges

Move to subscription renewal, then subscription.updated, then subscription.deleted. Same pattern for each: trace as spec, audit/fix loop, bring remaining items to Jessica.
