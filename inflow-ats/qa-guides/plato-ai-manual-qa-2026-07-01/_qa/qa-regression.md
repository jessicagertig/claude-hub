# QA — Non-AI regression (shared surfaces the Plato AI work touched)

Scope: NOT the AI feature. Each case spot-checks EXISTING non-AI behavior that runs through code the
Plato AI work rewrote or extended. The baseline to protect is the "nothing-AI-intended" state —
**flag-OFF org, NO fit filter active, normal plan** — which must behave exactly as production. UI-only:
verify by observing the app. Turn `AI_APPLICANT_SUMMARY` OFF for any case marked "flag off".

Only genuinely at-risk surfaces are listed; purely-additive LOW changes (new websocket cases, new
optional props, additive serializer keys) are omitted.

---

## 1. Billing & Stripe — plan flow rewritten around AI credit branches

The main Stripe webhook handler and `Organization#customer_subscription` plan-picker were both
rewritten. The picker now filters out any `credit`/`plato` subscription before choosing the plan, and
`free_plan` orgs no longer short-circuit. Every org's plan detection routes through this. Highest-value
regression area.

- **Plan upgrade AND downgrade** through the normal Plan & billing flow resolve to the correct plan —
  name, job/user limits, and features all reflect the change. A mismatched subscription id could now
  silently skip the plan update.
- **Trial → active** conversion lands on the correct paid plan.
- **`free_plan` org** still detects as free (it now runs the full picker instead of short-circuiting) —
  not mis-detected as another plan.
- **WWR / WhatJobs listing purchase** — buying a listing still publishes the job / activates the listing
  on payment (the webhook's listing branches were refactored to early `return`s).
- **Manage billing / Stripe portal** from the STANDARD Plan & billing page opens the portal and returns
  correctly; a failure still surfaces an error toast (portal flow moved from a parent callback to an
  internal mutation).
- **Org with vs. without a subscription** — a normal paid org and a no-subscription/`free_plan` org both
  behave sanely on billing (the `invoice.paid` guard moved, changing which orgs reach it).

## 2. Applicant intake & resume OCR — highest-traffic non-AI path extended

`enqueue_new_job_application` and the Textract pipeline changed: DOCX resumes now convert to PDF before
OCR, prior TextractResults are retained (not destroyed), and a companion status row is created for every
new applicant.

- **Apply with a PDF resume (flag off)** — applicant created, appears in the list, resume attached and
  extracted text available as before.
- **Apply with a DOCX resume (flag off)** — same result; .docx now converts to PDF first, so confirm the
  applicant is not stuck and the resume/text still lands.
- **Re-upload a resume** on an existing candidate — OCR re-runs and the newest resume/text wins (older
  TextractResults are now kept — confirm the candidate shows the latest, not a stale, resume).
- **Bulk candidate import** and **public job-board apply** still succeed with no failures/slowdowns (each
  new applicant now also does extra sync work + a new status row).

## 3. Candidate list & bulk actions with NO fit filter

The candidate-list query, bulk move, and bulk message all route through `apply_role_fit_filter` +
new `roleFit` params, and selection-count math changed. With no filter this must be a pure no-op.

- **List result set unchanged** — a stage's list shows the same candidates, order, and pagination as
  production. The "Filter by fit" dropdown is NOT feature-gated; its presence must not alter the default
  unfiltered list.
- **Bulk move, no filter** — select-all and a subset move the expected set; the toast and
  `bulk_move_completed` count are correct (count now comes from server `movedCount`). Confirm
  select-all and select-all-minus-exclusions target the same set as production.
- **Bulk message, no filter** — recipient set identical to production.
- **Selection-count math** — Select-All and excluded-count numbers on the stage menu match the visible
  list (source changed to `selectableCount ?? stage count`).
- **Non-AI job-app edits** (stage move, edit) refresh the stage list normally with no double-loading /
  visible churn (these mutations now also invalidate AI-summary cache keys, and the stage-list cache key
  is now roleFit-partitioned).

## 4. Left-nav & global page layout — shared across every page

- **Left-nav across ALL items (not just AI)** — the icon-reveal CSS selector was restructured for every
  nav item. Confirm each item still renders its chevron/count, hover reveals the trailing icon, and the
  active-item styling is intact. Check Jobs/Candidates/etc., the single highest-risk FE line.
- **Both app layouts load clean** — pages in the hiring app and the account/job-board app render fully
  with no console error. A new inline `window` global was added to the shared globals script; if it
  broke, dependent globals fail — so confirm recaptcha renders on auth pages and an embedded job board
  loads.
- **Account tabs (flag off)** — Users, Templates, API keys, Plan & billing all render and navigate; the
  Plato AI tab is absent.
- **Job Setup tabs (flag off)** — existing routes load and the job-description sidebar layout looks
  correct (a sidebar CSS change applies unconditionally); no Plato tab appears.

## 5. Hiring-document action relocation & candidate overflow menu

The "Overview options" dropdown on the candidate Overview header was REMOVED; Add/Edit hiring document
moved to the sidebar actions menu. This non-AI action must stay reachable everywhere.

- **Add/Edit hiring document reachable (flag off)** — available in the sidebar actions / overflow menu
  and opens the document modal. Confirm nothing else that lived in the removed Overview-options menu was
  lost.
- **`H` hotkey** still opens Add/Edit hiring document.
- **Candidate overflow menu** (renamed testid) — its other actions still open and fire.
- **Activity timeline intact** — the candidate activity feed renders normally for a candidate with no AI
  review (a new feed entry type was injected; a malformed item could regress the whole timeline).

## 6. Org lifecycle & plan gating

- **Org signup / creation** succeeds end to end — a synchronous AI-credit-state creation now runs inside
  the org-creation transaction; confirm signup does not fail or hang.
- **Org deletion** of an org with no AI rows still works (new `restrict_with_error` associations block
  deletion only when AI balance/purchase rows exist).
- **Org settings save** — existing non-AI settings round-trip correctly (new AI keys were added to the
  shared settings jsonb; verify nothing existing was clobbered).
- **Plan limits still enforced** — hit a plan's job or user limit and the gate fires exactly as
  production; denied-feature gating unchanged (new AI keys were merged into `plan_rules`).
- **Non-admin job edit still saves** — a normal job update by a non-admin user is unaffected (a new
  authorization branch was added only for the AI auto-generate key).
