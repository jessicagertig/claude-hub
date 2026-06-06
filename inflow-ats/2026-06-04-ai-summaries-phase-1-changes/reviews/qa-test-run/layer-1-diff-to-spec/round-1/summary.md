# Layer 1 Diff-to-Spec Review -- Round 1

15 agents reported. 13 deduplicated findings. All spec requirements covered by at least one agent.

---

**CRITICAL STRIPE FINDINGS -- Spec-Implementation Mismatches**

**F-001 (CRITICAL): invoice.paid top-up branch uses checkout session lookup instead of invoice metadata.** Three agents independently confirmed this. The spec (Note #4) says to grant credits using `organization_id` and `stripe_price_lookup_key` from the invoice metadata. The code instead calls `Stripe::Checkout::Session.list(payment_intent: ...)` -- an extra Stripe API roundtrip that the spec's design explicitly avoids. If the checkout session lookup fails, credits are silently not granted (log error only). The invoice metadata fields set by the controller (Note #4) are never read by this handler.

**F-002 (CRITICAL): charge.refunded handler deleted -- Note #33 explicitly says "no change."** The pre-existing `handle_charge_refunded` method and `charge.refunded` case were removed in commit fa9ccdb38. Note #33's approved decision reviewed this handler and explicitly decided to keep it: "No change. handle_charge_refunded handles ALL charge.refunded events, not just credit-pack refunds." This is a behavioral regression: credit-pack refunds will no longer trigger `ApplyAiCreditRefund`.

---

## All Findings

### F-001 -- invoice.paid top-up branch uses checkout session lookup instead of invoice metadata
- **Severity:** CRITICAL
- **Source agents:** stripe-webhook-1, stripe-webhook-2, stripe-webhook-3 (3 independent confirmations)
- **Spec requirement:** Note #4: "Add a branch to the invoice.paid handler keyed on `object.metadata['ai_credit_pack_top_up']` ... that grants the credits using the `organization_id` and `stripe_price_lookup_key` from the invoice metadata."
- **What the code does:** The branch (lines 182-191 of `stripe_webhook_handler_job.rb`) checks the correct metadata key but then calls `Stripe::Checkout::Session.list(payment_intent: object.payment_intent, limit: 1)` to look up the checkout session and passes it to `ApplyAiCreditPurchase.call(session: checkout_session, kind: :one_off)`. It does NOT use `organization_id` or `stripe_price_lookup_key` from the invoice metadata.
- **Evidence:** `app/jobs/stripe_webhook_handler_job.rb:183-190`
- **Impact:** Extra Stripe API dependency. Silent failure if lookup fails. Invoice metadata fields set by the controller are never consumed.

### F-002 -- charge.refunded handler and handle_charge_refunded method deleted
- **Severity:** CRITICAL
- **Source agents:** stripe-webhook-1, stripe-webhook-3 (2 independent confirmations)
- **Spec requirement:** Note #33: "No change. handle_charge_refunded handles ALL charge.refunded events, not just credit-pack refunds."
- **What the code does:** No `charge.refunded` case or `handle_charge_refunded` method exists in the current file. Both were removed in commit fa9ccdb38.
- **Evidence:** grep for `charge_refunded` returns no results in `stripe_webhook_handler_job.rb`
- **Impact:** Production regression. charge.refunded events silently ignored. Credit-pack refunds no longer processed.

### F-003 -- CREDIT_PACKS_BY_LOOKUP_KEY missing name: key from all four pack entries
- **Severity:** HIGH
- **Source agents:** model-purchase
- **Spec requirement:** Note #9B-1 gives an exact hash literal where each pack includes a `name:` key (e.g., `name: 'Credit Pack Top-Up -- Small'`).
- **What the code does:** All four pack hashes contain only `kind:` and `credits:` (or `credits_per_period:`). No `name:` key.
- **Evidence:** `app/models/organization_ai_credit_purchase.rb:4-21`
- **Impact:** Any caller reading `pack[:name]` gets nil.

### F-004 -- checkout action sets amount_cents_paid: 0 instead of nil
- **Severity:** HIGH
- **Source agents:** controllers
- **Spec requirement:** Note #9B-5 enumerates exactly the fields to set at checkout: `kind`, `stripe_checkout_session_id`, `stripe_price_lookup_key`, `subscription_credits_per_period`. Constraints section: "At checkout time no payment has been collected, so these fields are unknown."
- **What the code does:** Sets `amount_cents_paid: 0` explicitly.
- **Evidence:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:52`
- **Impact:** Misrepresents payment state. The validation relaxation exists so the field can be nil. invoice.paid will overwrite it, limiting functional impact.

### F-005 -- AI_TASKS_README.md missing two on-demand benchmark tasks
- **Severity:** HIGH
- **Source agents:** migrations-config
- **Spec requirement:** Note #19 requires five on-demand tasks including `ai:relevance_benchmark` and `ai:comparison_benchmark`.
- **What the code does:** Lists only three: `ai_credits:grant`, `ai_credits:show`, `ai:bulk_extract`.
- **Evidence:** `lib/tasks/AI_TASKS_README.md` lines 12-14
- **Impact:** Two tasks undocumented.

### F-006 -- AI_TASKS_README.md documents ai_credits:reconcile as weekly, not daily
- **Severity:** MEDIUM
- **Source agents:** migrations-config
- **Spec requirement:** Note #19 lists `ai_credits:reconcile` as daily under "Recurring tasks (Heroku Scheduler)."
- **What the code does:** README says "Runs weekly or on-demand after suspected drift."
- **Evidence:** `lib/tasks/AI_TASKS_README.md` line 7
- **Impact:** Scheduler misconfiguration risk.

### F-007 -- AccountContainer Plato AI route missing exact={false}
- **Severity:** MEDIUM
- **Source agents:** plato-ai
- **Spec requirement:** Note #16: "Add one route for /hire/settings/plato-ai with exact={false}."
- **What the code does:** Route has no `exact` prop at all.
- **Evidence:** `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx:206-211`
- **Impact:** React Router v5 `<Route>` without `exact` does prefix-match by default, so it likely works. Literal spec mismatch.

### F-008 -- Bulk job spec uses structural handler-order test instead of behavioral retry/discard test
- **Severity:** HIGH
- **Source agents:** tests
- **Spec requirement:** Note #25 TDD: "The spec stubs the pipeline to raise CustomErrorAiSummary during iteration and asserts the job is re-enqueued (retried), not discarded. Separately asserts that a non-CustomErrorAiSummary StandardError results in discard."
- **What the code does:** Tests `described_class.rescue_handlers` index ordering. Never stubs the pipeline or verifies retry/discard behavior.
- **Evidence:** `spec/jobs/bulk_generate_ai_summaries_job_spec.rb:72-88`
- **Impact:** TDD requirement not met. The second required assertion (non-CustomErrorAiSummary -> discarded) is entirely absent.

### F-009 -- Bulk job spec does not test discard_on and retry_on exhaustion blocks calling notify_failure
- **Severity:** HIGH
- **Source agents:** tests
- **Spec requirement:** Note #13: "notify_failure -- called from three places: discard_on block, retry_on exhaustion block, on_complete failure condition."
- **What the code does:** Only on_complete paths are tested. No tests for discard_on or retry_on exhaustion blocks.
- **Evidence:** `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` -- no describe/it block for these paths
- **Impact:** The most critical failure notification paths have zero test coverage.

### F-010 -- Mailer spec missing god_admin coverage
- **Severity:** MEDIUM
- **Source agents:** tests
- **Spec requirement:** Note #1: "admin_recipients returns User records for org_admin, org_owner, and god_admin."
- **What the code does:** Creates only owner, admin, member, and interviewer org users. No god_admin.
- **Evidence:** `spec/mailers/ai_credit_notification_mailer_spec.rb:7-32`
- **Impact:** god_admin regression risk undetected.

### F-011 -- Mailer spec does not assert to, subject, template_version, or tags
- **Severity:** LOW
- **Source agents:** tests
- **Spec requirement:** Note #1: "per-recipient message_params outputs for both low_credits and zero_credits (to, subject, template, template_version, tags, and variables)."
- **What the code does:** Only checks `params[:template]` and selected variables.
- **Evidence:** `spec/mailers/ai_credit_notification_mailer_spec.rb:47-51, 74-76`
- **Impact:** Incomplete message_params coverage.

### F-012 -- BulkJobApplicationAiSummaryResultMailer uses local variables instead of instance variables
- **Severity:** LOW
- **Source agents:** bulk-notifications
- **Spec requirement:** Note #13: "Pattern: app/mailers/job_resume_export_mailer.rb" (which uses @instance_variables).
- **What the code does:** Uses local variables (`user = User.find(user_id)` not `@user = ...`).
- **Evidence:** `app/mailers/bulk_job_application_ai_summary_result_mailer.rb:5-6`
- **Impact:** Functionally nil. These mailers use a template service, not ERB views. Pattern deviation only.

### F-013 -- Webhook spec invoice.paid top-up test validates the divergent implementation, not the spec
- **Severity:** MEDIUM
- **Source agents:** tests
- **Spec requirement:** Note #4: credits granted using invoice metadata.
- **What the code does:** Test mocks `Stripe::Checkout::Session.list` and `list_line_items` (the checkout-session-lookup approach). Does not stub `metadata['organization_id']` or `metadata['stripe_price_lookup_key']`.
- **Evidence:** `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb:47-82`
- **Impact:** Test validates F-001's divergent implementation. If F-001 is fixed, this test needs rewriting.

---

## Spec Coverage Summary

### Fully implemented (no deviations)

- Note #3 -- `.order(:created_at).last` fix
- Note #5 -- Enum rename cascade (all backend + frontend files)
- Note #6A -- AiCreditPacks -> OrganizationAiCreditPurchase references
- Note #6B -- role_category_groups.rb deleted
- Note #8 -- Flipper guard in reset_daily_ai_credits
- Note #9A -- Controllers, policies, routes, frontend hooks (all correct)
- Note #9B-2 -- prices action, planHelpers constants and function
- Note #20 -- Template rename (low)
- Note #26 -- prompt_text removal
- Note #27 -- Overdue reset logic removed, renamed
- Note #30 -- Sentry.capture_exception added
- Note #31 -- Variables::AI_DAILY_CREDIT_ALLOCATION and fallback
- Note #32 -- .reload calls removed
- Note #34 -- broadcast_ai_summary_failed rename and frontend handler
- Note #35 -- saved_change_to_id? removed
- Note #37 -- Misleading comment removed
- Note #38 -- Template rename (zero)

### Implemented with deviations

| Requirement | Deviation | Finding |
|---|---|---|
| Note #4 -- invoice.paid top-up | Checkout session lookup instead of invoice metadata | F-001 |
| Note #33 -- charge.refunded handler | Deleted instead of preserved | F-002 |
| Note #9B-1 -- pack definitions | Missing name: key | F-003 |
| Note #9B-5 -- checkout record creation | amount_cents_paid: 0 instead of nil | F-004 |
| Note #16 -- Plato AI route | Missing exact={false} | F-007 |
| Note #19 -- README | Missing 2 tasks, wrong schedule | F-005, F-006 |
| Note #25 -- TDD for retry/discard | Structural test, not behavioral | F-008 |
| Note #13 -- notify_failure test coverage | discard_on and retry_on paths untested | F-009 |
| Note #1 -- mailer spec | Missing god_admin, incomplete assertions | F-010, F-011 |

### Not covered by any agent

None. All spec requirements were checked by at least one agent.
