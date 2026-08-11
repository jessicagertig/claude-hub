# Subscription.updated — Agent-Sanctioned Whitelist (flow 3)

Forced / no-analog deviations the audit/fix loop discovered and the orchestrating agent whitelisted to unblock convergence while the owner was away. The audit reads this file alongside `SANCTIONED-subscription-updated.md` and does not flag anything listed here.

**Bar for inclusion:** the deviation is forced by our domain / data model / a genuine product difference between the AI-credit-pack subscription and the main plan, AND there is no way to match the analog without breaking correct behavior. NEVER whitelisted because a fix is hard. Each entry cites the analog it diverges from and why no match is possible. For Jessica's later audit.

---

## Round 1

W1. **Does NOT call `Organization#sync_with_stripe`** — ANALOG (`stripe_webhook_handler_job.rb:159`) calls `organization.sync_with_stripe`; OURS (`:125-148`) does not. Forced: `sync_with_stripe` (`organization.rb:539-542`) explicitly REJECTS any subscription whose first item's price `lookup_key` contains `'credit'` or `'plato'` — every credit-pack lookup_key matches. Calling it would never select the credit-pack subscription and would (re)write the org's main-plan columns/`plan`/`monthly_credits_remaining` from the org's actual main-plan subscription, corrupting unrelated state. No way to match without breaking correct behavior.

W2. **Does NOT call `Organization#stripe_update_default_payment_method`** — ANALOG (`:158`) calls it with `object.default_payment_method`; OURS does not. Forced: the org-level default payment method (`Stripe::Customer.update(... invoice_settings.default_payment_method)`, `organization.rb:630`) is owned by the main plan. A credit-pack addon subscription must not repoint the customer's org-wide default PM.

W3. **Operates on `organization_ai_credit_purchases` columns, does NOT write `organizations` columns (`stripe_current_period_end_at`, `stripe_subscription_status`, `stripe_cancel_at_period_end`, `stripe_subscription_id`, `plan`, `stripe_default_payment_method_on_file`) nor `monthly_credits_remaining`** — ANALOG writes these org/balance columns (`:153-157`, `organization.rb:568-580`, `:605`). OURS writes purchase-row columns only (`:135-141`). Forced by the data model; carries SANCTIONED #1 and the `sync_with_stripe`/plan-assignment product difference. Credit packs are an addon, not the monthly plan, so no `plan` assignment and no `monthly_credits_remaining` reset.

W4. **Does NOT trigger `Organization` `before_update`/`after_commit` callbacks or their side effects** (subscription-status notifications, plan-change jobs, automation-disabling, engagement reports, `can_send_bulk_messages`/`can_enable_linkedin`, past-due mailer) — ANALOG's `organization.update`/`sync_with_stripe` update fire `handle_before_update` (`organization.rb:976`) and `handle_after_commit_on_update` (`:987`). OURS updates `OrganizationAiCreditPurchase`, which has no such callbacks. Forced: a credit-pack status change must not fire main-plan lifecycle effects.

W5. **Reads `object.current_period_start` and populates `subscription_current_period_start`** — ANALOG never reads `object.current_period_start`; OURS reads it (`:139`) to fill the `subscription_current_period_start` column the analog's table lacks. Forced/no-analog: ours has a column the analog does not.

W6. **Makes zero Stripe API calls** — ANALOG makes 4-8 Stripe calls (`PaymentMethod.list`, `Customer.update`, `Customer.retrieve` x3, `Subscription.list`) via `stripe_update_default_payment_method` + `sync_with_stripe`. OURS makes none, reading only the webhook `object` and the local DB. Forced consequence of W1+W2: the calls live entirely inside the two methods ours correctly does not call.
