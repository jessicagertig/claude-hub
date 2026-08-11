# Slice map: Controllers + Pundit Policies

Scope: permit params, bulk actions, authorization for Plato AI (summaries/scoring + AI-credit billing), plus the SHARED bulk/list endpoints the feature modified.

## New AI controllers

### `Api::V1::AiJobApplicationSummariesController` (new)
- `create` — POST under a job application. Loads `current_organization.job_applications`, `authorize :ai_job_application_summary, :create?`, runs `ValidateAiSummaryGeneration` (renders its error if not success), then `CreateAiSummaryGeneration`. Renders the summary or model errors.
- `show` — loads the job application then the summary scoped to it, `authorize ai_job_application_summary` (record `show?`).
- USER-VISIBLE: single-candidate "Generate AI summary" and viewing an existing summary. Gated by credit availability (validation) and by `AiJobApplicationSummaryPolicy`.

### `Api::V1::BulkAiJobApplicationSummariesController` (new) — includes `RoleFitFilterable`
- `create` — `authorize :ai_job_application_summary, :bulk_create?`; finds job; resolves IDs via `resolve_job_application_ids`; calls `QueueBulkAiSummaryJobs`. Renders `{queued_count, skipped_count, any_textract_pending}`.
- `all_stages` — same auth; processes ALL of the job's job applications (`@job.job_applications.pluck(:id)`), passes `kind: 'all_stages'` and `rescore_requested`.
- `resolve_job_application_ids` (select-all pattern): if `included_job_application_ids` present → use them; elsif `hiring_stage_id` present → resolve stage's job_applications through `apply_role_fit_filter(..., role_fit)` minus `excluded_job_application_ids`; else `[]`.
- Params: `require(:bulk_ai_job_application_summary).permit(:job_id, :hiring_stage_id, :rescore_requested, included_job_application_ids: [], excluded_job_application_ids: [], role_fit: [])`.
- USER-VISIBLE: bulk "Generate/rescore AI summaries" for a filtered stage or whole job. EDGE: select-all on a role-fit-filtered stage only processes the visible (filtered) band, minus deselected rows; `rescore_requested` controls re-scoring in all_stages.

### `Api::V1::OrganizationAiCreditBalanceController` (new)
- `show` — `authorize :organization_ai_credit_balance, :show?`; renders the org's balance. Any org user can read.

### `Api::V1::OrganizationAiCreditPurchasesController` (new, large — billing)
Actions and their authorization:
- `show` — `:organization_ai_credit_purchase, :show?` (org user). Returns active/past_due subscription-kind purchase or `nil`.
- `checkout` — `:billing, :create_subscription?` (ORG ADMIN). Validates lookup key is a subscription plan, looks up Stripe price, creates a subscription-mode Checkout Session, saves a pending `OrganizationAiCreditPurchase` (kind subscription, stripe_amount 0). Returns `{redirectUrl}`. Success/cancel land on `/hire/settings/plato-ai/billing`.
- `purchase_top_up` — direct charge (card on file). Builds one_off purchase, `authorize record, :create?` (ORG ADMIN via OrganizationAiCreditPurchasePolicy#create?), saves, then `charge_for_purchase` model method. Rescues StandardError → "Unable to process payment".
- `purchase_top_up_checkout_session` — `:billing, :checkout?` (ORG ADMIN). No-card path; builds one_off purchase with `stripe_invoice_paid: false`, saves, creates payment-mode Checkout Session with invoice_creation + metadata `organization_ai_credit_purchase_id`. Returns `{url, sessionId}`.
- `cancel` — `:billing, :cancel_subscription?` (ADMIN). Calls `CancelAiCreditSubscription`.
- `revert_cancellation` — `:billing, :cancel_subscription?` (ADMIN). Requires `stripe_cancel_at_period_end`; calls `Stripe::Subscription.update(cancel_at_period_end: false)`, clears local flags.
- `cancel_scheduled_change` — `:billing, :change_subscription?` (ADMIN). `Stripe::SubscriptionSchedule.release(schedule_id)`.
- `prices` — `:organization_ai_credit_purchase, :prices?` (org user). Lists Stripe prices (expand tiers).
- `preview_subscription_change` — `:billing, :change_subscription?` (ADMIN). Stripe upcoming-invoice proration preview + default payment method.
- `preview_top_up` — `:billing, :checkout?` (ADMIN). Returns price amount, credits, default payment method.
- `update_ai_credit_subscription` — `:billing, :change_subscription?` (ADMIN). Upgrade = immediate `Stripe::Subscription.update` with proration; downgrade = `SubscriptionSchedule` two-phase (guards against an already-scheduled change).
- `customer_subscription` — no explicit authorize; enqueues `SyncAiCreditPurchasesWithStripeJob` (skipped in test env), returns `{subscription}`.
- `subscription_schedule` — `:organization_ai_credit_purchase, :show?`; retrieves a Stripe schedule's phases.
- Params: `require(:organization_ai_credit_purchase).permit(:stripe_price_lookup_key)`; checkout-session path uses bare `params.permit(:stripe_price_lookup_key)`; `determine_price_id` requires `params[:price_id]` else raises.
- EDGE: all subscription-lifecycle actions no-op with "No active AI credit subscription" if none in active/past_due; missing `stripe_customer_id`/`stripe_subscription_id` short-circuit with specific errors. Stripe errors → generic payment-processor message.

## New / changed policies

- `AiJobApplicationSummaryPolicy` (new): `create?`/`bulk_create?` → `can_use_ai_credits?` = org admin OR (org user AND org setting `hiring_team_ai_credits_control_enabled`). `show?` = on hiring team OR assigned interviewer. NOTE: org admins get `on_hiring_team? == true` unconditionally.
- `JobPolicy#update_ai_settings?` (new): delegates to `AiJobApplicationSummaryPolicy#can_use_ai_credits?`. Enforced in JobsController#update only when `auto_generate_ai_summaries` is in params.
- `OrganizationAiCreditBalancePolicy` (new): `show?` = org user.
- `OrganizationAiCreditPurchasePolicy` (new): `show?`/`prices?` = org user; `create?` = org admin (gates one-off top-up).
- Reuses existing `BillingPolicy` (`checkout?`, `create_subscription?`, `change_subscription?`, `cancel_subscription?` all = org admin). SHARED policy reuse; no change to BillingPolicy itself.

## SHARED / non-AI surfaces touched (regression risk)

1. **`RoleFitFilterable` concern (new) mixed into bulk message, bulk move, AND job applications list.** `apply_role_fit_filter` uses `relation.fit_bands(scored)` / `relation.unscored` scopes (Plato-score bands). If `role_fit` param absent/empty → returns relation unchanged (no behavior change). REGRESSION RISK: the candidate LIST query and both bulk endpoints now route through this filter; a bug in the scopes or param handling could drop/alter which candidates appear or are acted on even when no filter is intended.

2. **`BulkChannelMessagesController` (bulk email/message):** select-all and select-all-minus-exclusions now resolve stage IDs via `apply_role_fit_filter(stage.job_applications, role_fit)` instead of raw `job_application_ids`. Added `role_fit: []` to permit. REGRESSION: bulk messaging a full stage now depends on the role-fit filter; recipients could differ if a filter is active.

3. **`BulkMoveJobApplicationsToStageController` (bulk stage move):** same role-fit resolution + `role_fit: []` permit. Response now also returns `moved_count`. REGRESSION: bulk-move recipient set now filter-dependent.

4. **`JobApplicationsController#index` and `#show`:** index now `.includes(:ai_job_application_summary_status)` and wraps results in `apply_role_fit_filter(..., params[:role_fit])`; show adds the same includes. REGRESSION: the core candidate list ordering/pagination and the single-candidate load — non-AI critical path — were modified (added eager-load + filter wrapper).

5. **`JobApplicationsController#update` — Textract gating change:** now `if !job_application.resume_is_docx && Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, ...)`. DOCX resumes no longer submit directly to Textract (defer to `DocxToPdfJob`). REGRESSION: resume-upload flow behavior change for .docx uploads.

6. **`JobsController#update`:** added `authorize job, :update_ai_settings?` when `auto_generate_ai_summaries` present, and permitted `:auto_generate_ai_summaries`. SHARED job-update action gains an extra authorization branch — non-admin org users without credit control cannot toggle it.

7. **`OrganizationsController` settings permit:** added 5 keys (`auto_generate_ai_summaries_enabled`, `hiring_team_ai_credits_control_enabled`, `low_ai_credit_notifications_enabled`, `low_ai_credit_notification_threshold`, `zero_ai_credit_notifications_enabled`). SHARED org-settings update path.

8. **`Cypress::OrganizationsController#create_ai_credit_subscription` (new):** test-only endpoint calling `organization.setup_ai_credit_test_subscription` on `Organization.first`. Test infra only.

## Pipeline/model/provider
None in this slice — no scoring-pipeline provider/model files here (those live in jobs/services). Scoring appears only indirectly via `fit_bands`/`unscored` scopes and `ai_job_application_summary_status` eager-loads.
