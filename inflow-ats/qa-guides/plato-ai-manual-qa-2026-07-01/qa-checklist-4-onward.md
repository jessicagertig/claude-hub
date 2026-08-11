# Plato AI QA — §4 onward (clean checklist)

Each line: condition → expected. Cases marked **skip** are code-verified and not reproducible from the UI.

Sequencing worth knowing up front:
- Keep one org drained to 0 credits for the zero-credit cases (§4.4).
- Drive one Stripe subscription through its whole lifecycle in order — subscribe → downgrade → cancel → revert — and pick up §5.3–§5.7 as you pass through each state.

---

## 4. Bulk Generate

Entry points: whole-job ("Run Plato" CTA → Review-all modal) and per-stage (checkboxes → Bulk options → Generate AI summaries → confirm modal). "Already scored" = row shows fit swatch (`current`).

### 4.1 Whole-job CTA routing (precedence: description → no-candidates → review-all)
- [ ] No job description → Add-description modal, even with 0 candidates; "Edit job description" links into Job Setup; no API call
- [ ] Description + 0 candidates → No-candidates modal
- [ ] Description + candidates → Review-all modal; no API call until confirm

### 4.2 Review-all modal — count & rescore
Count = `rescore ? total : max(total − alreadyReviewed, 0)`
- [ ] Rescore OFF → count = unreviewed only
- [ ] Rescore ON → count jumps to full total; credit line recomputes
- [ ] All reviewed + rescore OFF → count 0, "Review all" disabled; ticking rescore re-enables
- [ ] Credit count N and balance X in the modal match live values

### 4.3 Per-stage confirm modal (always excludes already-scored; no rescore option)
`processableCount` = selection − loaded rows at `current`
- [ ] No selection → Generate disabled
- [ ] Every selected candidate already reviewed → Generate disabled
- [ ] Mixed selection, all rows loaded → exact count, excluding already-scored
- [ ] Select-All on a stage larger than one page (rows not all loaded) → switches to inexact "up to N" mode
- [ ] Select-All minus a few deselections → count = selectable − excluded − already-scored-loaded

### 4.4 Credit shortfall (both modals)
`shortfall = max(0, needed − available)`
- [ ] Needed > available → shortfall banner ("first {available} get summaries; the rest skipped"); submit still allowed (partial run, does POST)
- [ ] Zero available → validation blocks submit, no POST
- [ ] Balance query error → treated as 0 available — **skip**, not UI-inducible

### 4.5 Submit & async completion
- [ ] Skip rules: no resume or already-processing → skipped; already-reviewed dropped silently
- [ ] Per-stage success clears the selection
- [ ] Async: completion toast arrives via websocket without reload; result email arrives; rows refetch — swatches on reviewed, hourglass on in-progress

### 4.6 Role-fit filter interaction
- [ ] Filter applied + Select-All + Generate → only the filtered band processed (minus deselected, minus already-reviewed)
- [ ] No filter → whole-stage behavior unchanged
- [ ] Stage switch resets filters — Select-All right after acts on the full stage

### 4.7 Bulk menu
- [ ] Bulk menu absent on an empty stage

---

## 5. AI Credits Billing UI

Billing `/hire/settings/plato-ai/billing`, Usage `/hire/settings/plato-ai/usage`, Plan & billing handoff callout. Stripe-hosted flows: verify redirect + correct return landing only. Copy checks = correct plan name / count / date + correct outcome toast, not verbatim strings.

### 5.1 Access & handoff
- [ ] "AI credits — Manage AI credits" callout at bottom of Plan & billing on subscribed AND unsubscribed plan pages, NOT on free-trial page; navigates to Billing
- [ ] AI surfaces + callout are NOT plan-gated — free/no-plan org still shows them (no-plan orgs get 0 monthly credits; feature present, credit-gated)

### 5.2 Stripe return
- [ ] Return with `?ai_credit_subscribe_success` / `?ai_credit_top_up_success` → balance/subscription/purchase data refreshes once on mount; plain visit does NOT force refetch

### 5.3 Status banner
- [ ] Unsubscribed → no-subscription state + subscribe prompt + "Manage billing"
- [ ] Active → plan name, credits/month, real formatted renewal date (roll-over note) matching tier
- [ ] Scheduled to cancel → correct date; button swaps to "Don't cancel subscription"; Manage billing hidden
- [ ] `past_due` render + missing-period-end fallback — **skip**, needs failed Stripe renewal / test clock

### 5.4 Subscribe (unsubscribed org)
- [ ] Subscribe on a tier → straight to Stripe Checkout redirect, no in-app confirm

### 5.5 Change plan (active org)
- [ ] Button text per tier: higher → "Upgrade" (primary), lower → "Downgrade" (secondary), equal → "Change plan"; current tier → "Current plan" badge + "Cancel"; `_large` shows "Best value" unless current
- [ ] Change previews first, then confirm modal
- [ ] Modal: correct new plan name + credits/month; upgrade → prorated amount due today; downgrade → end-of-period date + "then {N} instead of {M}" counts

### 5.6 Scheduled change callout
- [ ] After downgrade → callout above tiers with correct from/to plans + date
- [ ] "Don't downgrade plan" → callout disappears, plan stays current

### 5.7 Cancel & revert
- [ ] Cancel modal: stops renewing, keeps credits, no further charge, correct "will not renew" date; confirm → banner scheduled-to-cancel
- [ ] Revert: "Don't cancel subscription" → banner back to active/renews

### 5.8 One-off top-up (forks on default payment method)
- [ ] Card on file → confirm modal; confirm → modal closes immediately, direct charge; server-pushed success growl + balance update when the webhook lands — growl is the ONLY success feedback on this path, absence = regression
- [ ] No card → straight to Stripe Checkout; return param refreshes balance
- [ ] Pack card numbers (price, credit count) match configured packs

### 5.9 Usage tab
- [ ] Three buckets (Monthly plan / Subscription / Top-up): remaining counts + reset dates correct; spend order monthly → subscription → top-up
- [ ] Total correct; Buy credits → billing page
- [ ] Zero balance → 0 total, no divide-by-zero artifact in the bar

### 5.10 Double-charge guard
- [ ] Confirm modals (subscription change + top-up) dismiss the moment Confirm is clicked, before the charge fires — double-click can't fire two charges

---

## 6. Non-AI Regression Spot-Checks

Baseline to protect: no fit filter, normal plan = exact production behavior.

### 6.1 Billing & Stripe plan flow (plan-picker + webhook rewritten)
- [ ] Real plan upgrade AND downgrade through normal Plan & billing → correct plan resolves (name, limits, features) — plan-picker now filters out credit subscriptions
- [ ] Trial → active lands on correct paid plan; free_plan org still shows free
- [ ] WWR / WhatJobs listing purchase → publishes/activates on payment
- [ ] Orgs with and without a subscription both sane on billing page (moved `invoice.paid` guard)
- [ ] Manage billing: standard Plan & billing → Stripe portal → returns `/hire/settings/billing`; Plato billing (subscribed org) → returns to Plato billing; unsubscribed org → `/hire/settings/billing`; promo-code dropdown still appears (active sub without coupon)

### 6.2 Applicant intake & resume OCR
- [ ] PDF apply → applicant created, in list, resume + extracted text present
- [ ] DOCX apply → same, not stuck (converts to PDF before OCR)
- [ ] Re-upload resume on existing candidate → OCR re-runs, latest wins (older TextractResults retained but not shown)
- [ ] Bulk candidate import succeeds at scale (each applicant now also creates a status row)
- [ ] Public apply flow creates candidate normally

### 6.3 Candidate list & bulk actions, no fit filter (must be a no-op)
- [ ] List set, order, pagination unchanged; filter dropdown's mere presence changes nothing
- [ ] Bulk move / bulk message: select-all and select-all-minus-exclusions target the same set as production; move toast count correct (server `movedCount`); recipient set identical
- [ ] Selection-count math on stage menu matches visible list, including stale/loading list
- [ ] Stage live updates: move/edit refreshes list normally, no double-loading (mutations now also invalidate AI-summary cache keys)

### 6.4 Hiring-document relocation & overflow menu
- [ ] Add/Edit hiring document reachable in sidebar actions menu, opens modal; `H` hotkey works; nothing else from removed Overview-options menu lost
- [ ] Candidate overflow menu actions still fire (testid renamed)
- [ ] Activity timeline intact for a no-review candidate

### 6.5 Left nav & layout
- [ ] All nav items: chevron/count render, hover reveals trailing icon, active styling intact (icon-reveal selector restructured for every item)
- [ ] Both app layouts load clean; recaptcha renders on auth pages; embedded job board loads (new inline `window` global)
- [ ] Account tabs: Users / Templates / API keys / Plan & billing all render/navigate
- [ ] Job Setup tabs: routes load, job-description sidebar layout correct (CSS change applies unconditionally)

### 6.6 Org lifecycle & plan gating
- [ ] Org signup succeeds end to end (synchronous AI-credit-state creation inside the org-creation transaction — no fail/hang)
- [ ] Org settings save round-trips existing non-AI settings (new AI keys in shared payload — nothing clobbered)
- [ ] Plan limits enforced: `job_limit` / `user_limit` / denied-feature gate fire as production
- [ ] Non-admin normal job edit still saves (new auth branch is AI-key-only)
- [ ] Job counts accurate, no drift after adding/removing applicants (new counter-cache columns)
