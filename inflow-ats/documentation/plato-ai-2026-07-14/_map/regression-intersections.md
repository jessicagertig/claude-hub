# Regression Intersections — where Plato AI touches SHARED / non-AI surfaces

Every file in `production...develop` is AI-related, but a subset modifies SHARED / cross-feature
code (serializers, shared components, cross-feature models, controllers, websockets, jobs, mailers,
plan gating). This note enumerates only those intersections and, for each: **the surface**, **the AI
change**, and **the plausible NON-AI breakage** to QA. Source: the sibling `_map/*.md` slice notes.

Legend for risk: **HIGH** = core non-AI path rewritten / unconditional change; **MED** = shared path
extended with gating; **LOW** = additive, existing behavior structurally untouched.

---

## TOP REGRESSION RISKS (verify these first)

| # | Surface | AI change | Plausible non-AI breakage |
|---|---|---|---|
| 1 | **`stripe_webhook_handler_job.rb`** (main Stripe webhook, shared with plan billing + WWR/WhatJobs listings) | AI credit-pack branches interleaved into `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.paid`; NEW `charge.refunded`. `invoice.paid` lost its upfront `raise CustomStripeSubscriptionMissingError` guard (moved into else); listing branches refactored to early `return`s; main-plan `subscription.updated` now gated on `object.id == organization.stripe_subscription_id`; main-plan `invoice.paid` else now also calls `reset_ai_credits`. | Main-plan subscription updates silently skipped if the event's sub id doesn't match the org's `stripe_subscription_id`. WWR/WhatJobs listing invoice handling (publish on payment) could stop firing after the early-`return` refactor. Any org without `stripe_subscription_id` set behaves differently at the moved guard. **QA: real plan upgrade/downgrade, plan invoice.paid, and a WWR/WhatJobs listing purchase → confirm they still process.** |
| 2 | **`Organization#customer_subscription` / stripe sync** (plan detection for ALL orgs) | Guard changed from `return if !stripe_customer_id.present? \|\| stripe_subscription_id == 'free_plan'` to `return unless stripe_customer_id.present?` (free_plan orgs no longer short-circuited). Now **filters OUT** subscriptions whose `lookup_key` includes `'credit'`/`'plato'` before choosing the plan subscription. `sync_customer` now grants full monthly allocation via `update_columns` on plan change. | Plan/trial detection and upgrade resolution for EVERY org routes through the rewritten picker. A free_plan org that previously short-circuited now runs the full path. **QA: normal plan detection, trial→active, and plan upgrades still resolve to the correct plan for non-AI orgs.** |
| 3 | **`JobApplication#enqueue_new_job_application`** (core new-applicant path — runs for every application, AI or not) | (a) Textract submission now gated on `!resume_is_docx` in addition to the Flipper flag (docx defers to `DocxToPdfJob`). (b) Auto-summary generation when `job.should_auto_generate_ai_summaries?`. (c) ALWAYS calls `find_or_create_ai_job_application_summary_status` (companion row for every new applicant). | New-applicant creation is the highest-traffic non-AI path. Docx resumes now take a different Textract route; a bug drops OCR for .docx. Extra synchronous work + a new row on every applicant (incl. bulk imports / public apply flow). **QA: apply with PDF vs DOCX resume, bulk candidate import, and applicant creation in a flag-OFF org — all still succeed and OCR still runs.** |
| 4 | **`NavItem.tsx`** (shared — EVERY left-nav item) | CSS selector for the hover/active icon reveal changed from `> svg` to `> *:last-child > svg` in `linkStyles` (base, `.active`, `:hover`); trailing content moved into a new `StyledRight` flex wrapper; new `rightContent` prop. | Restructures markup + icon opacity-reveal rules for ALL nav items, not just AI. Chevron/count could stop appearing or hover could stop revealing the icon across the whole left nav. **QA: every left-nav item — chevron/count render, hover reveals icon, active styling intact.** This is the single highest-risk line in the FE slice. |
| 5 | **`RoleFitFilterable` concern** (mixed into candidate list index + bulk move + bulk message) | `apply_role_fit_filter(relation, role_fit)` wraps the candidate-list query and both bulk endpoints' select-all resolution, using Plato-score `fit_bands`/`unscored` scopes. Returns relation unchanged when `role_fit` blank. | The core candidate LIST query and both bulk action endpoints now route through this filter unconditionally. A bug in the scopes or in "blank param → unchanged" handling could drop/alter which candidates appear or get acted on **even when no filter is intended**. **QA: candidate list, bulk move, bulk message with NO filter active — result set identical to production.** |

---

## SERIALIZERS (frontend data contract)

- **`JobApplicationSerializer`** (shared — every candidate/application render) — AI change: added
  `bulk_ai_summary_processing` (a per-record `...status_processing.exists?` query, **not preloaded**)
  and `has_one :ai_job_application_summary_status`. Non-AI breakage: **N+1 / query-count increase**
  on any endpoint returning many applications (candidate lists, pipeline views); frontend now expects
  these keys. Additive only; nothing removed. **MED**
- **`ShallowJobApplicationSerializer`** (shared — lightweight/large-collection lists) — same two
  additions. Higher N+1 risk because it is used exactly where large collections are returned. **MED**
- **`JobSerializer`** (shared — every job render) — added `auto_generate_ai_summaries`,
  `ai_job_application_summaries_count` (counter cache), `should_auto_generate_ai_summaries`. Non-AI
  breakage: job payload shape shifts; the count depends on the counter-cache column staying in sync
  (see jobs-table below). **LOW/MED**

## SHARED FE COMPONENTS / MODALS / LAYOUTS

- **`BulkMoveModal.tsx`** (shared, core non-AI action) — new `roleFit` prop into the move payload;
  success handler now reads `data.movedCount` from the server for both the `bulk_move_completed`
  analytics `candidates_count` AND the toast text, falling back to client `candidatesCount` only when
  `movedCount == null`. Non-AI breakage: bulk-move count/toast could be wrong; **every caller must now
  pass `roleFit`.** **QA: bulk move with no filter, select-all vs subset, and an older backend response
  (movedCount null) all show correct counts.** **MED**
- **`BulkMessageModal.tsx`** (shared) — new `roleFit` prop into the bulk-message payload. Non-AI
  breakage: recipient set becomes filter-aware; every caller must pass `roleFit`. **QA: unfiltered bulk
  message still targets the expected candidates.** **MED**
- **`ManageBillingActions.tsx`** (shared — used by non-AI `PlanCard`/`FreePlanCard`) — Stripe portal
  flow moved from a parent-supplied `onCreateBillingPortalSession` callback to an internal
  `useCreateStripeCustomerPortalSession` mutation with a `returnUrl` default; 5 parent files had the
  prop removed. Non-AI breakage: the ordinary "Manage billing" button on the standard Plan & billing
  page now depends on the internal mutation. **QA: non-AI account can still open the Stripe portal and
  return correctly; error toast still behaves.** **MED**
- **`FormCheckbox`** — new optional `description` prop switches the row to `align-items: flex-start` /
  column layout when present (`hasDescription`); `handleClick` logic unchanged. Non-AI breakage:
  existing checkboxes WITHOUT a description must render identically (single-row). **LOW**
- **`JobSetupDescription.tsx`** — sidebar `display: block → flex column` at `lg` applied
  **unconditionally** (the flag only gates the tip content, not the CSS). Non-AI breakage: description
  editor sidebar spacing/layout could shift for ALL orgs including flag-OFF. **QA: job description page
  sidebar with flag off.** **MED**
- **`JobSetupContainer.tsx`** — new nav item + route inserted **before** the `god_admin` polymerAdmin
  route. Non-AI breakage: route ordering / nav rendering for flag-OFF jobs (must not show the tab or
  404 other Job Setup routes). **LOW/MED**
- **`AccountContainer.tsx`** — new conditional "Plato AI" nav entry + `<Route>`. Non-AI breakage:
  spread-conditional / route ordering could interfere with existing account tabs (Users, Templates,
  API keys, Plan & billing). **QA: all pre-existing account tabs still render.** **LOW**
- **`ConfirmationModal.tsx`** — `subcopy` widened `string → React.ReactNode`. Additive; string callers
  unaffected. **LOW**
- **`DropdownMenu.tsx`** — new optional `badge` slot (absolute-positioned overlay). Additive. **LOW**

## CROSS-FEATURE MODELS

- **`Organization`** (heavily modified) — see TOP #2 for the `customer_subscription` rewrite. Also:
  `after_create :create_ai_credit_state_if_needed` runs **synchronously on EVERY org creation** (inside
  the org-creation transaction; rescued to Sentry+log); `dependent: :restrict_with_error` on the new
  balance/purchase associations means **org deletion now blocks if those rows exist**; `add_default_settings`
  writes 5 new AI keys into the shared settings jsonb for all new orgs. **QA: org signup/creation flow;
  org deletion; org settings serialization.** **HIGH** (creation path) / **MED** (deletion).
- **`Job`** — `handle_after_update_commit` now calls `handle_criteria_extraction_after_commit`, which on
  publish (status → published) OR a meaningful description change auto-extracts AI criteria (Flipper-gated,
  debounced, 30s re-extract delay). Non-AI breakage: adds work to the existing Job after_commit path. **QA:
  publishing / editing a job with the flag OFF is unaffected, and trivial description edits don't spam
  extraction.** **MED**
- **`TextractResult`** — new `after_commit :queue_ai_summary_job` on create/update; **prior TextractResults
  are no longer destroyed**, and `submit` now does `update_all(stale: true)` on `ai_job_application_summaries`.
  Non-AI breakage: the resume-OCR pipeline runs for all applicants with resumes; **any code elsewhere that
  reads `textract_results.first` could now read a stale/older row** (the two textract services here were
  updated to `.order(created_at: :desc).first`, but other readers are a risk). `GetResumeTextFromTextract`
  also switched `update_columns → update`, so TextractResult validations/callbacks now fire on the success
  path and could newly fail/side-effect. **QA: resume upload/re-upload and OCR completion for non-AI orgs.**
  **HIGH**
- **`jobs` table** — new counter-cache columns `ai_job_application_summaries_count` and
  `ai_job_criteria_generations_count` (counter_culture). Non-AI breakage: counters must stay in sync with
  child-row create/destroy; drift shows a wrong count badge; any job serializer/index returning these could
  shift job payloads. Backfilled by data migration `182505` (irreversible). **LOW/MED**
- **`Organization.settings` jsonb** — data migration `040802` writes 5 AI keys to EVERY existing org's
  settings via `update_settings`. Non-AI breakage: mutating the shared settings hash for all orgs — verify
  no non-AI setting was clobbered. **LOW**
- **`PlanFeatureGate`** (cross-feature — ALL plan gating: job limits, user limits, every `denied_features`)
  — added `AI_APPLICANT_SUMMARY` to `universal_features`; `plan_rules` gained two allocation keys on every
  plan entry, and three legacy `.merge(...)` plans changed from single-key to multi-key merges. Non-AI
  breakage: verify `job_limit` / `user_limit` / `denied_features` / legacy-plan values are UNCHANGED for
  every plan, and that any consumer iterating `plan_rules` tolerates the new keys. **MED**

## CONTROLLERS

- **`JobApplicationsController#index` / `#show`** — `#index` now `.includes(:ai_job_application_summary_status)`
  and wraps results in `apply_role_fit_filter(..., params[:role_fit])`; `#show` adds the same include. Non-AI
  breakage: the core candidate-list ordering/pagination and single-candidate load (a non-AI critical path)
  were modified. See TOP #5 for the filter concern. **HIGH**
- **`JobApplicationsController#update`** — Textract gating now `if !job_application.resume_is_docx &&
  Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, ...)`; .docx resumes no longer submit directly to Textract.
  Non-AI breakage: resume-upload behavior change for .docx uploads. **MED**
- **`BulkChannelMessagesController`** — select-all / select-all-minus-exclusions now resolve stage IDs via
  `apply_role_fit_filter(stage.job_applications, role_fit)` instead of raw `job_application_ids`; added
  `role_fit: []` to permit. Non-AI breakage: bulk-messaging a full stage now depends on the role-fit filter;
  recipients differ if a filter is active. **MED**
- **`BulkMoveJobApplicationsToStageController`** — same role-fit resolution + `role_fit: []` permit; response
  now also returns `moved_count`. Non-AI breakage: bulk-move recipient set is now filter-dependent. **MED**
- **`JobsController#update`** — added `authorize job, :update_ai_settings?` when `auto_generate_ai_summaries`
  is in params, and permitted that key. Non-AI breakage: the shared job-update action gains an extra
  authorization branch — non-admin org users without credit control cannot toggle it (but normal job updates
  must be unaffected). **LOW/MED**
- **`OrganizationsController` settings permit** — added 5 AI keys to `settings_params`. Shared org-settings
  update path; additive. **LOW**

## WEBSOCKETS

- **`WebsocketGlobalChannelHandler.tsx`** — new cases `AI_CREDIT_TOP_UP_COMPLETE`, `AI_SUMMARY_COMPLETE`,
  `AI_SUMMARY_FAILED`, `AI_SUMMARY_BULK_FAILED`, `AI_SUMMARY_BULK_COMPLETE` (toasts + cache invalidations).
  Non-AI breakage: shared handler; unknown/malformed payloads fall through `default` — existing cases
  structurally untouched. **LOW**
- **`WebsocketJobChannelHandler.tsx`** — new `ai_summary_status_change` case invalidating summary /
  jobApplication / stage-list keys. Note the stage-list key here is `[..., hiringStageId]` (no `roleFit`
  third element) and relies on react-query **prefix matching** to invalidate the roleFit-partitioned keys.
  Non-AI breakage: additive case only; risk is if prefix-match assumptions are wrong. **LOW**
- **`JobChannel.broadcast_to`** (backend) — `AiJobApplicationSummary#broadcast_status_change` after_commit
  pushes on `JobChannel`. Non-AI breakage: interactor specs assert the status read-model interactor is
  SILENT on this channel; stray pushes seen in QA = regression. **LOW**

## JOBS

- **`stripe_webhook_handler_job.rb`** — see TOP #1. **HIGH**
- **`docx_to_pdf_job.rb`** — after `handle_possible_docx_resume`, if `resume_is_docx` AND
  `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, org)` → enqueues `SubmitResumeToTextractJob`. Runs on the
  general resume-upload path for DOCX resumes; Flipper-gated per org so flag-OFF orgs see no change. Non-AI
  breakage: docx resume-upload flow; regression only if flag semantics change. **MED**
- **`get_resume_text_from_textract_job.rb`** — shared Textract job; added an exhaustion block
  (`cleanup_orphaned_summary`) and switched the success path `update_columns → update` (now fires
  validations/callbacks). Non-AI breakage: the update could newly fail/side-effect on save for the
  resume-OCR path. **MED**

## MAILERS / VIEWS

- **`layouts/account_application.html.erb` + `layouts/application.html.erb`** (global layouts on EVERY page
  of both apps) — added one line to the inline window-globals `<script>`:
  `window.AI_CREDIT_ALLOCATIONS = '<%= ENV["AI_CREDIT_ALLOCATIONS"]&.html_safe %>';`. Non-AI breakage: if
  `ENV["AI_CREDIT_ALLOCATIONS"]` contains an unescaped single quote it breaks the inline `'...'` JS string
  and could **break the entire globals script block on every page** (Sentry DSN, recaptcha, job-board embed
  URL would fail to populate). **QA: load any page in both apps, confirm no JS console error and other window
  globals still populate.** **MED**
- The 3 new mailers themselves (`AiCreditNotificationMailer`, both bulk result mailers) are AI-only and send
  via `Emails::SendTemplateEmail` wrapped in `.deliver_later` — no shared mailer modified. **LOW**

## FE SHARED TYPES / QUERY HOOKS

- **`shared/types/jobApplication.ts`** — base `JobApplication` interface widened with
  `aiJobApplicationSummaryStatus` + `bulkAiSummaryProcessing`. Non-AI breakage: every `JobApplication`
  consumer app-wide now type-expects these; undefined if the serializer omits them. **LOW/MED**
- **`useJobApplication.ts`** — (a) `useInfiniteJobApplicationsForStage` now puts `roleFit` in the query key
  `["jobApplicationsForStage", stageId, roleFit]`, **re-partitioning the cache for ALL stage-list rendering**
  (callers not passing roleFit get `[...,undefined]`); (b) `useUpdateJobApplication` onSuccess now ALSO
  invalidates `["aiJobApplicationSummary"]`, so **every** non-AI job-application mutation (stage move, edit)
  triggers an extra AI-summary refetch; (c) `bulkMoveJobApplicationsToStage` sends new `roleFit` (default []).
  **QA: stage list cache behaves; non-AI job-app edits don't cause unexpected extra refetch churn.** **MED**
- **`useBulkMessage.ts`** — `createBulkMessage` adds `roleFit` (default []) to the payload. Non-AI
  bulk-messaging flow carries a new param. **LOW**

## FE CANDIDATE LIST / SIDEBAR / STAGE MENUS

- **`JobApplicationActivity.tsx`** (Overview header, all candidates) — the "Overview options" `DropdownMenu`
  that held Add/Edit hiring document is **REMOVED** and replaced by a feature-gated `PlatoCtaButton`; the
  hiring-document action was relocated to the sidebar actions menu. Also injects a new `platoReview` feed
  entry. Non-AI breakage: **Add/Edit hiring document + the `H` hotkey must still be reachable in every org
  including flag-OFF** (the Overview options menu no longer renders at all — confirm nothing else lived in
  it); a malformed feed item could regress the activity timeline for ALL candidates. **MED/HIGH**
- **`JobApplicationSidebarActions.tsx`** — the Add/Edit hiring document button (with `H` ShortcutKey) is
  re-added here, opening `SharedDocumentModal`. **NOT feature-gated** — this is the relocation target of the
  above. **QA together with the item above.** **MED**
- **`JobStageMenu.tsx`** — Bulk Message / Bulk Move selection-count math now uses
  `stageSelectableCount = selectableCount ?? currentStage.jobApplicationsCount` (was raw
  `currentStage.jobApplicationsCount`) for allSelected and excluded-type counts. Non-AI breakage: bulk
  message/move candidate counts + Select-All/excluded math changed for ALL orgs. **QA: counts correct with
  no filter (falls back to stage count); `roleFit=[]` when unfiltered doesn't alter bulk behavior.** **MED**
- **`JobApplicationListContainer.tsx`** — header render gate changed from `!isEmpty(jobApplicationsForStage)`
  to `currentStage?.jobApplicationsCount > 0` for both the filter menu and JobStageMenu. Non-AI breakage:
  affects when the bulk-actions menu appears — edge case where count > 0 but the loaded page is empty, or a
  stale count. **LOW/MED**
- **`FilterSortMenu.tsx`** — the "Filter by fit" dropdown is **NOT feature-gated**; renders for all orgs
  whenever stage count > 0. Non-AI breakage: confirm this is intended for non-AI orgs (fit filters would
  match only unscored). **LOW**
- **`JobApplicationNavItem.tsx`** — now passes `rightContent` to the shared `NavItem` (see NavItem risk).
  Verify non-AI rows render unchanged. **LOW** (rolls up into NavItem HIGH).

## CONFIG / TEST-ID RENAMES ON SHARED COMPONENTS

- **Admin dashboard org-actions menu** — `data-testid` renamed `dropdown-menu → organization-actions-menu`
  on the shared admin component (`cypress/e2e/admin-dashboard.cy.js`). **QA: God-admin "Edit organization"
  still opens from that menu.** **LOW**
- **Candidate overview overflow menu** — `data-testid` renamed `overview-menu →
  job-application-sidebar-overlow-menu` (note the "overlow" misspelling). This is the shared candidate-detail
  sidebar overflow menu the AI work refactored. **QA: "Add hiring document" and other overflow-menu actions
  still work on the candidate page.** **LOW/MED**

---

## QA one-liner per layer (non-AI regression pass)

- **Billing/Stripe:** real plan upgrade/downgrade, plan `invoice.paid`, WWR/WhatJobs listing purchase, org
  with/without `stripe_subscription_id`, Stripe portal from standard Plan & billing → all still work.
- **Applicant intake:** apply with PDF and DOCX resume, bulk import, flag-OFF org → applicant created, OCR runs.
- **Candidate list & bulk actions:** list, bulk move, bulk message with NO filter → result set + counts match
  production; hiring-document add/edit + `H` hotkey reachable.
- **Nav & layout:** left-nav chevron/count/hover across all items; both app layouts load with no JS console
  error and all window globals populated; account/job-setup tabs render with flag off.
- **Org lifecycle:** org signup succeeds; org settings save; counter-cache job counts accurate.
