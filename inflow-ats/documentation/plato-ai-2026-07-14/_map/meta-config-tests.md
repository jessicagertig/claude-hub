# Slice map: infra / meta / config / tests

Scope: `Gemfile`/`Gemfile.lock`, `config/*`, `app/errors/*`, `cursor_rules/*`, `.chief/specs/*`, `.claude/CLAUDE.md`, `README.md`, `cypress/*`. These are plumbing, not screens — but two shared-UI test-id renames and the routes/env config gate everything the rest of the feature does.

## What changed (behavior, not line recap)

### Routes (`config/routes.rb`) — the API surface for the whole feature
New API v1 endpoints under the org namespace:
- `resource :ai_credits` (show) → `OrganizationAiCreditBalanceController` — current AI credit balance.
- `resource :ai_credit_purchases` (show) → `OrganizationAiCreditPurchasesController` with a large collection block: `checkout`, `purchase_top_up`, `purchase_top_up_checkout_session`, `preview_top_up`, `preview_subscription_change`, `update_ai_credit_subscription`, `cancel` (PUT), `revert_cancellation` (PUT), `prices` (GET), `customer_subscription` (GET), `subscription_schedule` (GET), `cancel_scheduled_change` (PUT). This is the entire AI-credit billing/Stripe surface (subscription buy/upgrade/downgrade/cancel/revert + one-off top-up + preview + schedule).
- `resources :bulk_ai_job_application_summaries` (create) + collection `all_stages` (POST) — bulk generate AI summaries for selected candidates or an entire stage.
- Nested under job_applications: `resources :ai_job_application_summaries` (show, create) — per-candidate summary fetch/generate.
- Frontend SPA catch-all route: `jobs/:job_id/stages/:stage_id/applicants/:job_application_id/ai` → `pages#root` — the new **"AI" tab** on the candidate detail page (Plato tab). Also `/hire/settings/plato-ai/billing` is the AI-credit billing settings page (seen in cypress).

### Env / global config (`config/initializers/01_variables.rb`)
Adds provider API keys (all read `ENV['STAGING_*']` first, then Rails credentials): `OPENAI_API_KEY`, `DEEPSEEK_API_KEY`, `MISTRAL_API_KEY`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`. Only OpenAI/Gemini are used by the scoring pipeline per project notes; the others are configured but may be unused.
Adds credit-allocation tunables:
- `AI_DAILY_CREDIT_ALLOCATION` (default 5), `AI_MONTHLY_CREDIT_MINIMUM` (25), `AI_MONTHLY_CREDIT_STARTER` (50), `AI_MONTHLY_CREDIT_GROWTH` (100), `AI_MONTHLY_CREDIT_SCALE` (150).
- `AI_CREDIT_ALLOCATIONS` — maps Stripe lookup keys → credit counts. Default hash defines BOTH a `plato_ai_credit_*` naming scheme (subscription small/medium/large = 500/1000/2000; top_up small/medium/large = 250/500/1000) AND an older `ai_credit_pack_*` scheme (subscription small/large = 500/2000; top_up small/large = 250/1000). Overridable via `AI_CREDIT_ALLOCATIONS` env JSON. **Edge case for QA:** the granted credit count on a purchase depends on the Stripe price's lookup key matching a key in this hash — a lookup key not present here maps to nothing.

### Gemfile
Adds `job-iteration` `~> 1.12.0` (Shopify) — used to batch/iterate the bulk AI summary jobs. No user-visible surface by itself; supports bulk-generate not timing out.

### Error class (`app/errors/custom_error_ai_summary.rb`)
New `CustomErrorAiSummary < StandardError` with a `param` reader. Used by the summary pipeline/jobs for typed failures (drives retry/exhaustion + failure display). Note: distinct from the pre-existing `CustomErrorStructuredExtraction`.

### Credentials (`config/credentials.yml.enc`)
Encrypted blob changed (added the openai/deepseek/mistral/gemini/anthropic keys for real envs). Not readable; nothing to QA directly.

### Docs / meta (no runtime behavior)
- `README.md` — flipper example flag changed from `CUSTOM_DOMAINS` to `AI_APPLICANT_SUMMARY`. Signals the feature is gated behind a `AI_APPLICANT_SUMMARY` Flipper feature flag — **relevant for QA: the AI tab/summaries may be dark unless this flag is enabled for the org.**
- `cursor_rules/core_critical_rules.md` — added rule 10 "Never Fabricate Fallback Values" (the `aiSummary?.id || 0` → 404 lesson), variable-naming-for-records section, and other rule renumbering. Docs only.
- Other `cursor_rules/*` (backend _base, background_jobs, pundit_policies, console_commands, boolean_variables_and_naming, react_hooks, public_api_controller_rules) — convention docs, no runtime effect.
- `.chief/specs/*.json`, `.claude/CLAUDE.md` — agent/spec metadata, no runtime effect.

## SHARED / non-AI surfaces that could regress
1. **Admin dashboard org-actions menu test-id rename** (`cypress/e2e/admin-dashboard.cy.js`): `dropdown-menu` → `organization-actions-menu`. The underlying shared admin component's `data-testid` was renamed. QA the God-admin admin dashboard "Edit organization" flow still opens from that menu.
2. **Candidate overview overflow menu test-id rename** (`cypress/e2e/candidates/overview-shared-document.cy.js`): `overview-menu` → `job-application-sidebar-overlow-menu` (note the misspelling "overlow"). This is the shared candidate-detail sidebar overflow menu used for "Add hiring document" and other non-AI actions. **Regression risk: the AI tab work refactored the candidate sidebar overflow menu.** QA that "Add hiring document" and any other overflow-menu actions on the candidate page still work.
3. **Cypress support** (`cypress/support/commands.js`): new `createAiCreditSubscription` command hitting `POST /cypress/organizations/create_ai_credit_subscription` (test-only seed endpoint). No prod surface.

## Cypress coverage present for AI billing
`cypress/e2e/plans-and-billing/ai-credit-billing.cy.js` (new): drives `/hire/settings/plato-ai/billing` — displays active AI credit subscription + upgrades tier (preview → update), and displays one-off top-up purchase cards + opens the purchase confirmation modal. Confirms these user flows: view subscription, upgrade tier, buy one-off top-up.

## For the scoring manifest
No pipeline/model/prompt code in this slice. Contribution: provider API keys wired (`OPENAI_API_KEY`, `GEMINI_API_KEY` are the live ones per project notes; DEEPSEEK/MISTRAL/ANTHROPIC also configured). Credit economics live in `AI_CREDIT_ALLOCATIONS` + `AI_MONTHLY_CREDIT_*` / `AI_DAILY_CREDIT_ALLOCATION`. Typed failure class `CustomErrorAiSummary(param)`. Feature flag gate: `AI_APPLICANT_SUMMARY`.
