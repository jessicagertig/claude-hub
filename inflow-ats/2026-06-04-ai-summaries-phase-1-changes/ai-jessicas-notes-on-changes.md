# AI Features — Jessica's Notes on Changes

Working notes on things to revisit or change. Ordered by priority — the highest-impact items (confirmed bugs and decided changes surfaced during the spec verification) are at the top; the rest follow.

---

### 1. BUG (HIGH) — AI Credit Notification Emails Never Send (`is_admin?` vs `is_admin`)

`AiCreditNotificationMailer#admin_recipients` (`ai_credit_notification_mailer.rb:62`) calls:

```ruby
organization.organization_users.select(&:is_admin?).map(&:user).uniq
```

But `OrganizationUser` defines `is_admin` with NO question mark (`organization_user.rb:54-56`, body `org_admin? || is_owner`). There is no `is_admin` column (so ActiveRecord generates no `is_admin?` predicate) and no `is_admin?` alias anywhere in `app/`. So `select(&:is_admin?)` raises `NoMethodError` on the first org user, and BOTH `low_credits` and `zero_credits` raise before sending anything.

Net effect: the entire low-credit / zero-credit email notification feature is non-functional — no such email can ever be delivered. Fix: change the call to `&:is_admin` (the existing method). Worth a spec/Cypress test covering recipient selection so this doesn't regress silently. This is independent of note #20 (Mailgun templates not yet created) — even once the templates exist, this bug would still prevent sending.

### 2. `AiResumeStructuredData` TS Type Out of Sync With Backend

The frontend type `AiResumeStructuredData` (`app/javascript/shared/types/aiJobApplicationSummary.ts`) declares `totalYearsExperience`, `relevantYearsExperience`, and `jobTitleRoleCategory`. But the backend pipeline (`generate.rb`) writes into `structured_data`: `total_months_experience` (months, NOT years), plus `assessment`, `months_by_domain`, and `comparison`. It never writes `relevantYearsExperience` or `jobTitleRoleCategory` (grep across `app/` + `lib/` = zero occurrences). The `AiJobApplicationSummarySerializer` passes `structured_data` through verbatim, so the API actually sends `totalMonthsExperience` + `assessment`/`monthsByDomain`/`comparison`.

Net: the type describes three fields the API never sends (one misnamed years/months, two nonexistent) and omits the fields it does send. Any frontend code reading `totalYearsExperience`/`relevantYearsExperience`/`jobTitleRoleCategory` off this type gets `undefined`. Fix: reconcile the type with the actual backend `structured_data` shape — rename to `totalMonthsExperience`, drop the two nonexistent fields, add `assessment`/`monthsByDomain`/`comparison` (or whatever subset the UI needs). Check `AiJobApplicationSummaryFeedItem.tsx` for reads of the bad field names.

### 3. Refund Picks Earliest Credit Row — Wrong for Refund-After-Renewal

`ApplyAiCreditRefund` looks up the original credit row with `purchase.ai_credit_balance_transactions.where(entry_type: purchase_credit_entry_types).order(:created_at).first`. For a subscription that has renewed one or more times, this picks the first-invoice credit row, not the most recent renewal. A refund on the latest charge would debit only the original (first-invoice) amount, not the renewal amount, leaving the bucket inflated by the difference. Needs fixing: either pick the credit row matching the refunded `stripe_invoice_id` / `stripe_charge_id`, or pick the latest renewal credit and cap from there.

### 4. Stripe Checkout `mode: payment` Discriminator Is Brittle

`StripeWebhookHandlerJob` decides a `checkout.session.completed` webhook is a credit-pack top-up by checking `object.mode == 'payment'`. The controller does set `ai_credit_pack_top_up: 'true'` in the session metadata, but the handler does not currently read it. Inflow-ats has other one-off Stripe payment flows (e.g., WrkRemotelyIn job-board listings) which also use `mode: 'payment'`. If any of those land in this handler, they'd be misrouted as credit-pack top-ups. Two fixes possible: (a) read the metadata key the controller is already setting and require it for credit-pack routing, or (b) restructure the webhook dispatch so each payment-mode flow has its own discriminator. Need to audit current `mode: payment` checkout flows in the codebase first.

Confirmed directly (`stripe_webhook_handler_job.rb:58-62`): `object.mode == 'payment'` is the SOLE branching condition — there is no metadata check, no lookup-key check, no product check at this branch. Any `checkout.session.completed` with `mode == 'payment'` is routed to `apply_top_up_checkout` and the handler returns early. The only thing downstream that could catch a non-credit-pack session is the `stripe_price_lookup_key` inclusion validation inside `ApplyAiCreditPurchase`/`OrganizationAiCreditPurchase` (reads the lookup key via `list_line_items`), so a foreign `mode: payment` session would fail validation there rather than create a bogus credit grant — but it's still mis-routed into the credit-pack path and errors, rather than being handled as whatever it actually was. That registered-keys validation is an accidental backstop, not an intentional guard.

### 5. Rename `auto_generate_ai_summaries_setting` Enum — DECIDED

Drop the `_setting` suffix and rename the values. New enum on `jobs`:

- Field: `auto_generate_ai_summaries_setting` → `auto_generate_ai_summaries`
- Values: `inherit` (0) → `default`, `on` (1) → `enabled`, `off` (2) → `disabled`

Reads as: "Auto-generate AI summaries default / enabled / disabled". `default` matches the defer-to-parent naming precedent from the social share image setting (`settings['social_share_image_type']` → `default`/`custom`/`none`).

Ripple effects to handle in the rename: the migration/column name, `Job#effective_auto_generate_ai_summaries_enabled?` resolver, the org-level `default_auto_generate_ai_summaries_enabled` setting, frontend enum values (`JobSetupAiSettings.tsx`), and any `_prefix: true` predicate call sites.

Naming-collision watch: with `_prefix: true`, the `enabled` value generates `auto_generate_ai_summaries_enabled?` — which sits next to the org boolean `default_auto_generate_ai_summaries_enabled?` and the resolver `effective_auto_generate_ai_summaries_enabled?`. Three near-identical predicate names with different meanings. Confirm this is acceptable or adjust the resolver name during the rename.

### 6. Credit Pack Definitions Location — DECIDED

Move `AiCreditPacks` (frozen hash, lookup methods) from `config/initializers/ai_credit_packs.rb` into the `OrganizationAiCreditPurchase` model as constants and class methods. Delete the initializer. The data defines what constitutes a valid purchase — it belongs on the model that validates against it. All callers (controllers, interactors, webhook job) will reference `OrganizationAiCreditPurchase` instead of `AiCreditPacks`.

Also: delete `app/services/role_category_groups.rb` — dead code, zero references anywhere in the app.

### 7. Subscription Cancellation Should Not Refund Remaining Balance — RESOLVED

Code already handles this correctly. `CancelAiCreditSubscription` does not call `ApplyAiCreditRefund`. The interactor only sets `cancel_at_period_end: true` on Stripe and marks the local purchase as canceled. Existing addon_subscription credits are preserved. The `charge.refunded` webhook handler remains intact for manual Stripe-initiated refunds.

### 8. Daily Credits — Keep Infrastructure, Control via Config

The daily credit bucket may not ship initially but should remain easy to turn on later. Considerations:

- Daily credits could be useful as a promotional tool (sometimes granted, sometimes not)
- When daily credits aren't active, the daily credits UI should not render
- The infrastructure is already built (model bucket, reset interactor, rake task, PlanFeatureGate allocation)
- Need a way to control this via variables and/or feature flags so it can be toggled without code changes
- Stripping it out entirely would be more work to add back than keeping it dormant
- The daily allocation in PlanFeatureGate could be set to 0 or nil for plans that don't include it — `ResetDailyAiCredits` already handles nil allocation by skipping
- Frontend needs to conditionally hide daily credit display when allocation is 0

### 9. Query Hooks Need Consolidation

We have too many query hook files. They were created almost one-per-action, which is not how we do things. Current state:

- `useAiJobApplicationSummary.ts` — has both generate (mutation) and fetch (query). **Correct.**
- `useBulkGenerateAiSummaries.ts` — separate file for bulk action. **Correct** (bulk actions get their own hook).
- `useAiCreditSubscription.ts` — query
- `useSubscribeToAiCreditPack.ts` — mutation (subscribe)
- `usePurchaseAiCreditTopUp.ts` — mutation (purchase)
- `useCancelAiCreditSubscription.ts` — mutation (cancel)
- `useOrganizationAiCreditBalance.ts` — query (remaining credits)

The last four (subscription, subscribe, purchase, cancel) should be consolidated into one file — maybe called `useAiCreditBilling.ts`. All of them involve money and credits. `useOrganizationAiCreditBalance` might also belong there, though it's about remaining credits not money. That one draws from a different controller (`ai_credits#show` vs `ai_credit_subscriptions`), but that should be fine.

The two controllers involved (`AiCreditsController` and `AiCreditSubscriptionsController`) could potentially be consolidated into one AI credit billing controller, but that's less important than the query hook consolidation. Having four separate hooks when we should have one or two is atrocious.

### 9B. AI credit pack bugs found in live flow testing — broken into sub-issues

The pack registry was built on fabricated Stripe lookup keys/amounts, and the AI-credit subscription corrupts the main plan's subscription slot. Independent sub-issues, to be tackled one at a time. (All structural specifics below — file lists, exact write paths — are leads only and must be reinvestigated.)

**9B-1 — Correct the pack identifiers.** The pack registry uses fabricated lookup keys that don't exist in Stripe: `ai_credits_{starter,growth,scale}_{one_off,subscription}` (50/150/500 credits). The real packs are:

- `ai_credit_pack_top_up_small` — one-off, 100 credits
- `ai_credit_pack_top_up_large` — one-off, 1000 credits
- `ai_credit_pack_subscription_small_monthly` — subscription, 500 / month
- `ai_credit_pack_subscription_large_monthly` — subscription, 2000 / month

The two subscription products are standalone — not bundled with the main plan subscriptions. Update the registry (now on `OrganizationAiCreditPurchase` per #6A), the frontend tier definitions, and the specs.

**9B-2 — Fetch pack prices/product data from Stripe; never hardcode.** The frontend shows tier credit amounts but no prices, and does no Stripe price fetch. Mirror the plan-billing pattern (`BillingController#prices` → `Stripe::Price.list`, route `GET /api/v1/billing/prices`): fetch Stripe prices filtered to the AI credit pack lookup keys and send them to the frontend, which renders prices from that fetch.

**9B-3 — Stop the AI-credit subscription from clobbering the main plan.** `organizations` has a single `stripe_subscription_id` (one-subscription assumption), but an org can now hold two concurrent Stripe subscriptions (main plan + AI credit pack). Unguarded write paths overwrite `stripe_subscription_id` (and status/period/plan) with the AI-credit subscription, so Plan & Billing shows the AI pack instead of the real plan (verified live). Scope every write to `stripe_subscription_id` and every read of the customer's subscription list to plan-vs-credit-pack — the `customer.subscription.updated`/`.deleted`/`invoice.paid` handlers already guard via `AiCreditPacks.subscription_key?`; the unguarded paths (including `Organization#sync_with_stripe`'s subscription selection) are the bug. Related: #4.

### 10. Architecture Diagram Inconsistency — Policy Methods

The technical map shows methods for `AiJobApplicationSummaryPolicy` (create?, show?, bulk_create?) but not for `AiCreditPolicy` or `AiCreditSubscriptionPolicy`. Should be consistent.

### 11. Two Serializers — INVESTIGATED, pending review

Investigation finding: The existing billing controller (`billing_controller.rb`) returns raw Stripe JSON with no serializers at all. The AI credit serializers exist because they return local app state (bucket balances, purchase records) not raw Stripe data. Two serializers serving two different data shapes. Jessica has not reviewed this yet.

### 12. Rename ConsumeAiCredits — INVESTIGATED, pending review

Investigation finding: The interactor's sole effect is creating one `AiCreditBalanceTransaction` ledger row (entry_type: ai_summary_usage_debit, amount: -1, bucket selected by priority). It validates balance exists, picks the right bucket (daily > monthly > addon_subscription > addon), creates the row, and `counter_culture` handles the rest. Nothing else happens. Proposed rename to `CreateAiCreditBalanceTransaction` — Jessica has not confirmed.

### 13. Add Email Notification on Bulk AI Summary Completion

When a bulk AI summary job finishes, send an email notification to the user who triggered it. The user is already passed into `QueueBulkAiSummaryJobs` and the user_id is in the `BulkGenerateAiSummariesJob` payload, so this should be straightforward. Currently only a WebSocket toast is sent on `on_complete`.

### 14. Table Review — INVESTIGATED, pending review

Investigation findings:

**OrganizationAiCreditPurchase:** It's the idempotency key for Stripe webhook retries (keyed on stripe_checkout_session_id / stripe_subscription_id). Without it, duplicate credit grants are possible. Also links purchases to ledger transactions and tracks subscription period dates.

**AiApiRequest:** The aggregate methods on AiJobApplicationSummary (`total_cost`, `total_input_tokens`, `total_output_tokens`) are defined but never called anywhere. The table is purely debug/audit. Credits are flat-rate (1 per summary), not cost-based.

Jessica has not reviewed these findings.

### 15. Scoring Pipeline — Services Are Prepped

The AI provider services and pipeline architecture are already in place for adding scoring. However, scoring may require combining existing calls or adding new ones to the pipeline. The 4-call structure may need to become 5+ calls, or some calls may be merged. This will be determined when scoring is designed.

### 16. Consolidate AI Tabs — Follow Integrations Pattern

Current state: three separate sidebar tabs (AI Usage, AI Billing, AI Settings). Too many for one feature.

**Decided direction:** One sidebar entry with chevron, following the `AccountIntegrationsContainer` pattern. Inside: `AccountPlatoAiContainer` (or similar) with its own internal sidebar listing Settings, Billing, and Usage as sub-pages. Individual sub-pages are separate components.

**Naming:** Leaning toward "Plato AI" as the feature brand. Short enough for the sidebar. Enables future CTAs like "Get Plato's take on this" for generate/scoring actions. Other candidates considered: Prism (not favorite), one other P-word (not recalled).

**Non-admin visibility:** Non-admins currently see 3 tabs (User preferences, Message templates, Review templates). Adding a 4th just for AI usage is probably overkill. Leaning toward non-admins not getting a Plato AI tab at all.

**Billing sub-page must render active AI credits (moved from 9B):** an active AI-credit subscription with a non-zero balance currently shows nothing in the billing panel. The Billing sub-page must display the active subscription and balance. Likely partly downstream of 9B-1 (wrong keys → no active purchase created) and 9B-3 (clobbering), so confirm after those.

### 17. Credit Balance Visibility for Non-Admins — Open Question

Non-admins need to know their org's credit balance somewhere, but where is undecided. The existing `AiCreditBalanceDisplay` widget is built for a full page (progress bar, sections) — not suitable for a compact header element. A header indicator would need a new, smaller component.

The staleness-across-users concern is handled: WebSocket events already invalidate `organizationAiCreditBalance` on every summary completion, so any component using the hook would stay current.

No clear SaaS precedent for showing credits persistently. Most credit-based systems show balance at point of purchase or point of consumption. The bulk modal and summary trigger area already show some balance info. May be sufficient to enhance those existing touchpoints rather than add a persistent display. Decision deferred — revisit when looking at the UI during implementation.

### 18. Trial-to-Paid Credit Transition Needs Serious Thought

Credit allocation happens at org creation, which is fine. But subscribing (converting from trial to paid) is different. We do get an `invoice.paid` even for the zero-dollar invoice when a free trial starts. We probably want a different (lower) credit allocation for free trialers regardless of which plan they choose to trial, since they haven't paid us. The transition goes from trialing → one of: active (converted), unpaid, or overdue. This has nitpicky edge cases that need to be worked through carefully.

### 19. Cron Jobs — Heroku Scheduler + Documentation

Cron jobs will be scheduled via Heroku Scheduler, which is only available on the production app. Need to note when they should be set up and do it at deploy time.

We should create a README in the tasks directory (`lib/tasks/`) documenting: what the current Heroku Scheduler tasks are, what they do, and how often they run. This way we don't have to check Heroku Scheduler directly and it's portable if we ever change scheduling tools.

### 20. Mailgun Templates Need to Be Created

The mailer templates (`ai-credits-low`, `ai-credits-zero`) referenced in `AiCreditNotificationMailer` need to be built in Mailgun.

### 21. Resume Re-Upload Should Show Confirmation Modal

Rather than silently consuming a credit on re-upload when auto-generate is on, add a confirmation modal so it's a manual decision every time. The modal would only be relevant for users with auto-generate enabled.

### 22. Do NOT delete AiRelevanceBenchmark yet — keep until the entire feature is complete

`app/services/ai_relevance_benchmark.rb` and `lib/tasks/ai_relevance_benchmark.rake` are retained ON PURPOSE. They will be deleted eventually, but ONLY after this whole feature is finished — they are kept for later pricing analysis. Do NOT delete them as part of any current work, and do NOT add their deletion to any spec or plan. (Repeated note to future agents: leave these alone.)

### 23. Schedule AI Credits Reconciliation as Automatic Housekeeping

The `ai_credits:reconcile` rake task should be added to Heroku Scheduler as a regular automatic housekeeping job, not just an on-demand tool.

### 24. Bump BulkGenerateAiSummariesJob Max Runtime

10 minutes may be too tight. The MAX_RUNTIME covers the entire iteration, not per-summary. Should bump it up to give larger batches room to complete in fewer job-iteration cycles.

### 25. Pipeline Error Handling — Swallowed Exceptions Skip Retries

The `generate` method in `AiJobApplicationAction::Summary::Generate` has three rescue branches. Only the `CustomErrorAiSummary` branch re-raises; the `JSON::ParserError` and `StandardError` branches swallow the exception. Because the job-layer retry is `retry_on CustomErrorAiSummary`, AI provider errors and JSON parse errors never trigger a retry — only AR validation failures on `ai_summary.update` do. Decide whether this is intentional (e.g., don't retry on malformed model output) or a gap.

### 26. AiJobApplicationSummary.prompt_text — Write-Only Debug Breadcrumb

`prompt_text` on `AiJobApplicationSummary` is written twice during a successful run: first after Call 1 as a JSON-encoded array of Call 1's messages, then at the end with a JSON-encoded hash keyed by call type (`extraction`/`assessment`/`comparison`/`summary`) with each value being that call's messages array. On failure paths, `prompt_text` is not written by the rescue blocks, so it ends up retaining whatever Write A left (or `nil` if Call 1 itself failed before the first update). No callers anywhere — never serialized to API, never read by UI, never referenced in specs. Decide whether to keep, drop, or formalize this debug data.

### 27. Remove `OVERDUE_RESET_GRACE` Constant

`OrganizationAiCreditBalance::OVERDUE_RESET_GRACE = 6.hours` is defined on the balance model but only referenced once — inside `period_overdue?` on the same model. The matching SQL scope in `Organization.process_overdue_ai_credit_resets` uses a hardcoded `6.hours.ago` literal instead. Two places where six hours matters, one uses the constant, one doesn't. Either centralize on the constant or remove it. Lean toward removing — we don't use a lot of constants in this codebase, and inconsistently-applied constants are worse than no constants.

### 28. AI Credit Allocation Constants — Inconsistent Usage

`PlanFeatureGate` defines `MINIMUM_AI_CREDIT_ALLOCATION = 25`, `STARTER_AI_CREDIT_ALLOCATION = 50`, `GROWTH_AI_CREDIT_ALLOCATION = 100`, `SCALE_AI_CREDIT_ALLOCATION = 250`, `DAILY_AI_CREDIT_ALLOCATION = 5`. The enterprise plan does NOT have a matching constant — `plan_ats_tier_enterprise` uses a bare `500` literal. Either add `ENTERPRISE_AI_CREDIT_ALLOCATION = 500` and use it, or remove all five allocation constants and inline the numbers. Pick one.

### 29. Daily Reset — Idempotency Check Outside Transaction

`ResetDailyAiCredits` wraps only the two ledger writes in a transaction. The "already reset today" idempotency check (querying for a `plan_daily_allocation_credit` since UTC midnight) runs outside any transaction or row-level lock. Two concurrent cron invocations could both see "no prior reset" and both insert. Compare to `ResetAiCredits` (monthly) which wraps allocation resolution + writes end-to-end. Either widen the transaction to include the idempotency query with a `SELECT … FOR UPDATE` on the balance row, or add a unique constraint on `(organization_ai_credit_balance_id, entry_type, date_of_created_at)` for the daily allocation entry type.

### 30. `create_ai_credit_state_if_needed` — Silent Failure on Money-Critical Record

`Organization#create_ai_credit_state_if_needed` (the `after_create` callback that backs every org's balance row) rescues exceptions and only logs them — no re-raise, no escalation. If creation fails the org exists without an `OrganizationAiCreditBalance`, and downstream code (`ConsumeAiCredits`, balance reads) will encounter a missing balance and either fail loudly later or return nothing. For a money-critical record, the silent rescue should be reconsidered: either re-raise to abort the organization-creation transaction, or send an alert when the rescue fires.

### 31. PlanFeatureGate Unknown-Plan Fallback Asymmetry

`PlanFeatureGate#monthly_ai_credit_allocation` falls back to `MINIMUM_AI_CREDIT_ALLOCATION` (25) for any plan key not in `plan_rules`. `daily_ai_credit_allocation` returns `nil` for the same case. So an org on a typo'd or newly-added plan silently gets 25 monthly credits but zero daily credits. Decide what the intended behavior is for unknown plans (most likely: error out loudly, since an unknown plan key is a deployment bug).

### 32. `ApplyAiCreditRefund` Uses `.reload`

`apply_ai_credit_refund.rb:21` calls `.reload` on the balance record. CLAUDE.md rule 17 prohibits `reload` in application code (only allowed in specs). The data-flow reason for the reload should be diagnosed and the fix should be to ensure the balance reference is fresh upstream, not to paper over staleness with `.reload`.

### 33. Webhook Silently Drops Refunds When Purchase Isn't Matched

`StripeWebhookHandlerJob#handle_charge_refunded` returns silently (`return unless purchase`) when it can't match the refunded charge to a purchase via `stripe_subscription_id` (subscription path) or `stripe_checkout_session_id` (one-off path). A refund that doesn't match any local record disappears with no log entry, no Sentry capture, nothing. For money-touching code, this should at minimum log loudly or alert — a real refund landing in this branch means either bad data or a routing bug we won't notice until a customer complains.

### 34. `AI_CREDITS_EXHAUSTED` Action Name Mismatches Its Trigger

`TextractResult#queue_ai_summary_job` broadcasts `AI_CREDITS_EXHAUSTED` whenever the re-run of `ValidateAiSummaryGeneration` fails — for ANY of seven reasons (job application missing, org missing, Flipper disabled, no resume, no credits, no textract result, textract failed twice). The frontend handler at `WebsocketGlobalChannelHandler.tsx:231-242` has a hardcoded credit-specific toast ("could not be generated — your organization is out of AI credits") that's shown unconditionally. Six of the seven failure paths display this lie to the user.

The validator returns distinct human-readable error strings per branch but no symbolic `code:` / `reason:`. To fix cleanly:
1. Add a symbolic `reason:` to each `context.fail!` in `ValidateAiSummaryGeneration` (e.g., `:credits_exhausted`, `:no_resume`, `:textract_failed`, `:textract_processing`).
2. Have `broadcast_credits_exhausted` (rename to something like `broadcast_ai_summary_failed`) read the reason and either emit a single action name with a `reason` payload field, OR branch on a small set of action names. The `AI_SUMMARY_COMPLETE` payload already carries an `errorMessage` field — same pattern.
3. Update the frontend to render an appropriate toast per reason.

Flipper-disabled isn't a real concern (if it's disabled, the user can't trigger anything to begin with), but the other five non-credit branches all need correct messaging.

### 35. `saved_change_to_id?` Check in `queue_ai_summary_job` Is Redundant

`TextractResult#queue_ai_summary_job` (`textract_result.rb:96-97`) gates with:

```ruby
return unless textract_job_result_text.present?
return unless saved_change_to_textract_job_result_text? || saved_change_to_id?
```

Per commit `6f7b08ac3` the `|| saved_change_to_id?` was added to "cover the create case where every column shows as saved_change but we want to fire." But that's not how AR dirty tracking works — on a fresh record, `saved_change_to_textract_job_result_text?` already returns true when text is set at insert. And in production the text is never set at insert anyway (`SubmitResumeToTextract` builds with only `textract_job_id` and `textract_job_status: 'in_progress'`; `GetResumeTextFromTextract` adds text later via `update`). The `|| saved_change_to_id?` adds no behavior the first predicate doesn't already provide and can be removed.

### 36. `PlanFeatureGate` Does Not Actually Gate AI Summaries

`AI_APPLICANT_SUMMARY` is in `PlanFeatureGate#universal_features` and NOT in `free_plan_denied_features` — so `PlanFeatureGate#allow?(AI_APPLICANT_SUMMARY)` returns true for every plan, free included. The only thing currently keeping AI summaries off free plans is the Flipper flag check in `ValidateAiSummaryGeneration` and `QueueBulkAiSummaryJobs`.

Decide: (a) add `AI_APPLICANT_SUMMARY` to `free_plan_denied_features` so plan-level gating actually enforces "no AI summaries on free," or (b) accept that Flipper is the sole gate and document it that way. Either way the current state is inconsistent with the apparent intent.

### 37. Misleading Comment in `plan_feature_gate.rb`

Line 76 of `app/services/plan_feature_gate.rb` reads: `# Universal features available to all tier 1 and tier 2 paid plans`. But the actual code applies `universal_features` to free plans too (via `available_features = all_features - denied_features`, and `free_plan_denied_features` doesn't deny most of those features). The comment misrepresents the behavior — it shaped at least one downstream document (the AI system spec) before being corrected. Fix the comment to match the actual scope.

### 38. Rename `ai-credits-low` and `ai-credits-zero` Mailgun Template Names

The template names referenced in `AiCreditNotificationMailer` (`ai-credits-low`, `ai-credits-zero`) use an `ai-` prefix that doesn't fit the codebase convention. All user-facing Mailgun templates use the `user-` prefix (e.g., `user-resume-export-ready`, `user-data-export-ready`, `user-subscription-past-due`). Rename to `user-ai-credits-low` and `user-ai-credits-zero` (or similar) when the templates are created in Mailgun (see #20).
