# Orchestrator Decisions Log

Every judgment call I (the orchestrating agent) made that went beyond a literal instruction — accepted scope, unblock/override calls during the audit loop, forced analog-matches. Surfaced to Jessica for review. Some may be wrong; all are reversible.

---

## Step 0 (implementation baseline)

**D1 — Grant-once guard corrected to sanctioned form.**
The stash baseline had `return if existing.ai_credit_balance_transactions.exists?(entry_type: :one_off_credit_pack_purchase_credit)`. The Step-0 verify flagged it; repair changed it to the sanctioned pattern (SESSION-PROMPT.md lines 102-110, SANCTIONED-DEVIATIONS.md):
```ruby
existing_grant = existing.ai_credit_balance_transactions.find_by(entry_type: :one_off_credit_pack_purchase_credit)
return if existing_grant && existing_grant.amount.positive?
```
`apply_ai_credit_purchase.rb:64-67`. Not one of the 4 enumerated Step-0 changes, but the prompt makes this exact form a HARD rule. **Accepted** — staged into the baseline. Revert review: low risk, it now matches the mandate.

**D2 — One-off `finalize_stripe_payment` removed from interactor.**
`ApplyAiCreditPurchase#apply_one_off` previously called `existing.finalize_stripe_payment`. Removed; finalize now lives only in the `invoice.paid` webhook one-off branch, matching WWR (`create_on_wwr` does not finalize; the handler does). Part of correctly wiring change 3. **Accepted** — staged. (Subscription path keeps its own `finalize_stripe_payment` at `:118` — that's a Step-2 concern, untouched.)

---

## Step 1 — one-off audit/fix loop unblock decisions

(appended live as I make them)

### Round 1 — flags (NOT my decisions; fix-agent actions I'm surfacing)

**R1-A — Fix agent created a NEW FILE: `app/jobs/notification/paid_ai_credit_pack_purchased_job.rb`.**
To satisfy DEV 10 (signaling tail), which requires invoking the model's pre-existing `broadcast_purchase_complete` — that method referenced `Notification::PaidAiCreditPackPurchasedJob`, which did not exist (invoking it would raise NameError). Fix agent created it, modeled on `Notification::PaidWwrListingCreatedJob`, including a live Slack webhook (`SLACK_3RD_PARTY_PURCHASES_WEBHOOK`). Analog-faithful but substantial new fix-agent code with external (Slack) side effects.
**RESOLVED (Jessica, round-1 discussion): FINE. Keep — it matches the analog. Analog-faithfulness outranks the flag; she'll remove it herself if she doesn't want it.**
**PRINCIPLE: do not block agents from analog-faithful additions (incl. new files). Stay out of their way on faithfulness; surface, don't obstruct.**

**R1-B — Round 1 reversed Step 0 decision D2 and (I believe) got the analog backwards.**
DEV 8 moved one-off `finalize_stripe_payment` out of the `invoice.paid` webhook branch and into `ApplyAiCreditPurchase#apply_one_off`. But the actual WWR analog webhook calls `listing.finalize_stripe_payment` THEN `listing.create_on_wwr` (finalize lives in the handler; `create_on_wwr` does not finalize). So R1 introduced a deviation.
**RESOLVED (loop self-corrected, rounds 2-3): webhook one-off branch now calls `organization_ai_credit_purchase.finalize_stripe_payment` then `.grant_credits` inline (`stripe_webhook_handler_job.rb:249-252`), iota-for-iota with WWR's `finalize_stripe_payment`+`create_on_wwr`. Finalize is back in the handler. No decision needed.**

### Round-discussion rulings (Jessica)

**#1 (new job file) — FINE.** Keep; analog-faithful. She removes it herself if unwanted. PRINCIPLE: don't block analog-faithful additions, incl. new files.

**#2 (finalize placement) — RESOLVED by loop self-correction.** No decision.

**#3 (interactor dismantled → inlined `grant_credits`) — ACCEPTED.**
- Subscription analog likely has no interactor either → flow #2 will probably move `apply_subscription` to the same model-method pattern. The one-off/subscription asymmetry is temporary, converging to inline. Not a concern.
- Large architectural refactor IS flag-worthy but IS IN SCOPE for this audit. **PRINCIPLE: for this loop, analog-matching refactors are in-scope — surface them, do not block/stop them.** (The general "minimal fix / no unscoped additions" rule still applies to NON-analog-driven additions.)

---

## INCIDENT — round 7 (loop stopped)

**Symptom:** deviation count spiked 7 → 16 (trend 18→11→11→14→8→7→16). Tripped the oscillation-stop criterion.

**Root cause:** a loop agent audited the WRONG REPO. round-7-audit.md describes the 85-line baseline (`amount_cents_paid`, `apply_one_off`, single checkout path, no `finalize_stripe_payment`) — that is the MAIN checkout `/Users/jessica/wrk/wrk-corp/inflow-ats`, NOT the `billing-bonanza` worktree. 7 inflow-ats worktrees exist; the agent wandered. The "16" is spurious — IGNORE round-7-audit.md in trend analysis.

**State verified intact:** worktree has all Step 0 + rounds 1-6 work (rename done; `grant_credits`/`finalize_stripe_payment`/`charge_for_purchase` present; interactor subscription-only). Main checkout AI-credit files = 0 changes (agent only READ). Step 0 baseline still staged (24 files). Real current count ≈ 7.

**Second hazard:** agents ran git commands — `reset: moving to HEAD` + 3 agent-created stashes (`WIP on billing-bonanza`, `temp-schema-oneoff`, `billing-deviation-fixes-temp-verify`). No loss but a real risk. Stashes left untouched (Jessica's call).

**Hardening proposed before resume (awaiting Jessica):**
1. Hard-pin every agent to the worktree: absolute root, operate ONLY there, absolute paths, verify pwd, NEVER touch any other inflow-ats checkout.
2. Forbid ALL git operations in agents (no stash/reset/checkout/add/commit/restore); files via Edit/Write only.

## Sanctioned additions (Jessica-approved, added to SANCTIONED-DEVIATIONS.md items 6/7/8)

Per Jessica's explicit approval, I added three items to SANCTIONED-DEVIATIONS.md (one-off section):
- **#6 Pricing follows the subscription analog, not WWR** (Stripe::Price.list, `price: price.id`, frontend price fetch). Audit was mis-comparing pricing to WWR; the trace already maps it to subscription (data-fetching section).
- **#7 No `job` association** (omit job wrapper/guard/job_id metadata/job.build).
- **#8 Action `purchase_top_up` not `create`** (authorize :billing, :checkout?).

Confirm modal (`PurchaseAiCreditTopUpConfirmModal`) VERIFIED intact + wired (`AiCreditSubscription.tsx:21,199,203`) — already SANCTIONED #1 (required deviation). Not stripped.

## Resume: v5 hardened run

Fresh run in `oneoff-rounds-v5/` (not resumed — clean slate against converged code). Audit prompt changes are ONE-OFF-FLOW-ONLY (do NOT propagate the pricing→subscription remap to the 3 subscription flows; their analog already IS the subscription handler):
- Hard-pin every agent to the `billing-bonanza` worktree; never touch other inflow-ats checkouts.
- Forbid all git operations.
- Pricing data (obtain/frontend/send-to-Stripe) judged vs the subscription analog per trace's data-fetching section; WWR for everything else.
