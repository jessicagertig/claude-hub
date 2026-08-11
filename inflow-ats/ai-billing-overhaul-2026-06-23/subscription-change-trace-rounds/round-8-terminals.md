# Round 8 — TERMINALS segment audit (SCREEN / STRIPE / DATABASE)

Subject: ANALOG subscription-change / upgrade-downgrade Stripe Billing Portal flow.
Worktree audited: /Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza
Trace audited: /Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/traces/subscription-change-analog-trace.md

Scope: every point data reaches the SCREEN (AccountBillingPlans / PlanCard / AccountBilling renders + redirects),
goes to STRIPE (each Stripe:: call + args), or touches the DATABASE (each column read/written, incl. sync_with_stripe).

## Result: 0 discrepancies in the terminals segment.

Every terminal the trace names was verified identifier-by-identifier, line-by-line, against the live analog code.
All SCREEN, STRIPE, and DATABASE terminals — including line numbers, exact identifiers, and the structural
claims about which terminals are gated/conditional/dead — match the actual code.

### STRIPE terminals verified
- `Organization#stripe_subscription` → `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })` — organization.rb:477. MATCH (called 2× from customer_subscription: :608 + :614).
- `BillingController#prices` → `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` — billing_controller.rb:537. MATCH.
- `determine_price_id` else-branch → `Stripe::Price.list({ active: true, limit: 10, expand: ['data.tiers'] })` — billing_controller.rb:634; `.data.find { lookup_key == DEFAULT_PRICE_LOOKUP_KEY }` :637. MATCH (note: limit 10 distinct from prices' limit 20).
- `ValidateSubscriptionChange` → `Stripe::Price.retrieve(target_price_id)` — validate_subscription_change.rb:15. MATCH.
- `change_subscription_portal_session` → `Stripe::BillingPortal::Session.create(options)` — billing_controller.rb:306; options flow_data verbatim :290-304. MATCH.
- `update_payment_method_and_subscription_portal_session` → `Stripe::BillingPortal::Session.create(options)` — :363; payment_method_update options :351-361, return_url :360, after_completion redirect :357. MATCH.
- `continue_change_subscription_portal_session` → `Stripe::BillingPortal::Session.create(options)` — :452; subscription_update_confirm options :433-447. MATCH.
- `sync_with_stripe` upstream → `Stripe::Subscription.list({ customer:, limit: 3, status: 'all' })` via `stripe_customer_subscriptions` — organization.rb:482. MATCH.
- `sync_with_stripe` → `Organization#stripe_customer` → `Stripe::Customer.retrieve({ id:, expand: ['subscriptions'] })` — organization.rb:471 (used :530/:578/:580). MATCH.

### DATABASE terminals verified
- `ValidateSubscriptionChange`: `organization.jobs.where(status: 'published').count` — validate_subscription_change.rb:42 (jobs table, status column, READ). MATCH.
- `ValidateSubscriptionChange` create-branch reads `organization.stripe_subscription_status` — :58 (DB column READ). MATCH (dead on action_type 'change').
- `PosthogTrackJob#perform`: `User.find_by(id: user_id)` — posthog_track_job.rb:7 (users table READ). MATCH.
- `sync_with_stripe` conditional writes: stripe_subscription_id/stripe_subscription_status/stripe_current_period_end_at only inside `if current_subscription.present?` — organization.rb:567-571; unconditional `plan` :573 and `stripe_default_payment_method_on_file` :580; diff-build :585-595; `update(changes_to_make)` :600 (organizations row WRITE, differing subset only). MATCH.
- `sync_with_stripe` AI allocation: `if changes_to_make.key?('plan') && organization_ai_credit_balance` :603 → `PlanFeatureGate.new(self).monthly_ai_credit_allocation` :604 (plan_feature_gate.rb:134) → `organization_ai_credit_balance.update_columns(monthly_credits_remaining:)` :605 (organization_ai_credit_balances WRITE). MATCH.
- Schema columns: organizations.plan integer default 101 — schema.rb:1052; stripe_subscription_id :1056; stripe_current_period_end_at :1058; stripe_subscription_status :1065; stripe_default_payment_method_on_file default false :1066. MATCH (trace cites :1052 plan, :1056 sub id).

### SCREEN terminals verified (AccountBillingPlans / PlanCard / AccountBilling)
- customer_subscription render terminals: `render json: { subscription: nil }` :611; `render json: { subscription: current_organization.stripe_subscription }` :614; error `render json: { errors: ['Unable to load subscription'] }` :618. MATCH.
- prices render: `render json: price_list` :540. MATCH.
- `currentSubscription` derivation AccountBillingPlans.tsx:62-64; `currentPriceObject` :67; trialing block :370-382; cancelAtPeriodEnd block :384-396; legacy display :412-414; isTrialing render `{isTrialing && !hasCoupon && \`Free for ${trialEndDays}.\`}` :415; hasCoupon promo :424-431. MATCH.
- Loading early-return `<LoadingIndicator label="Loading..." />` :352-354. MATCH.
- PlanCard map :435, isCurrentPlan :436, `<PlanCard>` :439-456 with all props :443-455. MATCH.
- PlanCard internals: displayPrice :90 / `${displayPrice}` :183; savings :91 / "You are saving ${savings} per year" :170 / "Save ${savings}/year" :178; showCurrentPlanBadge :160 → "Current plan" badge :167; button branch :199, ManageBillingActions :200-205, else Styled.Button :207-214 (loading={isLoadingButton} :209, disabled={isLoading} :210, styleType :211, `{plan.buttonText}` :213). MATCH.
- `subscriptionItemId` is a DEAD PROP — declared PlanCardProps :71, absent from destructure :75-89, never referenced. MATCH.
- Portal-path onSuccess `window.location.href = data.redirectUrl` :303; onError addToast :305-314. Payment-method onSuccess redirect :263 / onError :265-274. MATCH.
- Hook DEBUG/invalidate terminals: useChangeSubscriptionViaStripePortal logger :185-188 + invalidate :189; useUpdateWithPaymentMethod logger :198-201 + invalidate :202. MATCH.
- Continue-endpoint redirect terminals: raw `params[:return_url]` early guards :392/:397; computed return_url :403-407; missing-params redirect :411; validation-fail redirect :427 + return :428; happy `redirect_to session.url` :457; rescue redirects :463/:469. MATCH.
- update_payment_method action: `render json: { redirectUrl: session.url }` :367; continue_url built :346-349; StandardError rescue calls Sentry :377 (distinct from change action's :324-326 which does NOT). MATCH.
- AccountBilling parent: useBillingPrices :50, billingPrices `.data`/`[]` unwrap :54, 3-way ternary :122-134 gating AccountBillingPlans (only when hasActiveSubscription && !eligibleForFreeTrial). MATCH.
- ANALYTICS/DEBUG terminals (correctly NOT classified as SCREEN by the trace): currentPlanLookupKey trackEvent :339 + PlanCard plan_selected :99 + logger :156; currentPlanBillingPeriod logger :157; currentProductPrice logger :200. MATCH.

### Transport / routes / policies verified (terminal-adjacent)
- apiGet allKeysToCamel :22; apiPost :25-28 → apiMutate :40-68; CSRF :50; allKeysToSnake :52; allKeysToCamel response :67 / error :56. MATCH.
- Routes: change_subscription_portal_session POST :169; update_payment_method... POST :170; prices GET :174; customer_subscription GET :177; continue... GET :178. MATCH.
- Policies: prices? :4-6 → is_org_user? (app_policy :54-56); change_subscription? :24 → is_org_admin? (:50). MATCH.

No wrong file:line, no renamed identifier, no omitted terminal, no thread stopped short of its terminal,
no mis-classified terminal (screen vs Stripe vs DB) found in this segment.
