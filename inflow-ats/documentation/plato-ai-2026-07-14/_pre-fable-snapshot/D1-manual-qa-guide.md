# Plato AI — Manual QA Guide

Scope: everything in the Plato AI feature — candidate AI summaries (auto + manual + bulk generation), the Plato review tab and its display/state machine, AI-credits billing (subscription + one-off top-up), and the non-AI surfaces the work rewrote (Stripe plan flow, applicant intake/OCR, candidate list + bulk actions, left-nav, org lifecycle). Assumptions: you built this and are testing solo in one sitting, UI-only (no console/db/API). Cases state WHAT to verify and under WHAT condition, not click-by-click steps; a few notes name the page/tab to reach. Unless a case says otherwise, run as an **admin** on an org with the `AI_APPLICANT_SUMMARY` flag **ON** and a **non-zero** AI credit balance. Reach settings via Account → Plato AI (Settings / Usage / Billing sub-tabs); reach the review tab via a candidate drawer → **Plato** sidebar item. Flag-OFF and no-filter cases are grouped in the regression section at the end.

**Pre-arrange test-org states (batch the state-dependent cases).** Several high-value cases need credit/subscription states that are expensive to reach UI-only. Arrange each state once and run the cases that share it together rather than rebuilding per case:
- **Zero-credit org** — keep one org drained to 0 total credits so every zero-credit check batches: §2.3 (silent no-op), §3.4 (no-credits terminal states), §4.4 (zero-available submit block). The non-admin out-of-credits gating in §3.4 and §3.5 is the same mechanism — verify it once.
- **One subscribed org through its whole lifecycle** — drive a single Stripe subscription in sequence (subscribe → schedule a downgrade → cancel → revert) so §5.3, §5.5, §5.6, and §5.7 reuse it instead of rebuilding a subscription for each.

---

## 1. Enablement & Settings

**Prioritize — §1.2 is the expensive item.** Its override-precedence permutations are full auto-gen cycles (upload + OCR + AI wall-clock wait), NOT toggle checks — batch them into the §2 auto-gen session below and skip the §2.1 duplicate. The rest of §1 is cheap UI toggles/guards.

### 1.1 Org-level auto-generate toggle (Account → Plato AI → Settings)
- **Toggle persists both ways.** Setting "Auto-generate Plato reviews for new applicants" Enabled/Disabled saves (success toast "Plato AI settings saved"), clears dirty state, and survives reload.
- **Default OFF for a fresh org.** An org that never saved Plato AI settings shows the toggle Disabled — new applicants are not auto-reviewed until an admin turns it on.
- **Unsaved-changes guard.** Changing the toggle then navigating away triggers the guard; discarding leaves the stored value unchanged.
- **Copy accuracy.** Field copy states each successful review spends one credit and that individual jobs can override — confirm it matches the §2 behavior.

### 1.2 Per-job override + resolution cascade (Job Setup → Plato AI tab)
Job value is default / enabled / disabled; effective decision = job-enabled→on, job-disabled→off, job-default→inherit org. Verify by creating a NEW applicant on the job (that is the trigger — §2.1). Each permutation is a full auto-gen cycle (upload + OCR + AI wait), so batch these applicant creations into the §2 auto-gen session rather than running them as standalone settings checks — only the three override-precedence permutations below need their own cycles.
- **Org ON + job "default"** → fires — this case IS §2.1's happy path; confirm it there and do NOT run a duplicate cycle. **Org ON + job "disabled"** → does NOT fire (job beats org).
- **Org OFF + job "enabled"** → fires (job beats org). **Org OFF + job "default"** → does NOT fire.
- **Select defaults to "default"** on a never-configured job and the saved value round-trips through reload.

### 1.3 Authorization gating
- **Admin can always change the per-job setting.** Condition: admin, Job Setup → Plato AI.
- **Hiring-team member gated by `hiringTeamAiCreditsControlEnabled`** (Account → Plato AI → Settings): as a non-admin, with it ON the per-job auto-generate change saves; with it OFF the save is rejected (authorization). This is the only auth branch on the shared job-update action — confirm a normal non-AI job edit by the same non-admin still saves.

### 1.4 Nav visibility & route access (applies to all Plato AI settings pages)
- **Nav entry is flag-gated.** "Plato AI" appears in the account-settings left nav only with the flag ON; flag OFF ⇒ no nav entry and no AI-credits callout anywhere.
- **Route is admin-gated, not flag-gated.** With the flag OFF, hitting a Plato AI settings URL directly still mounts the container — the real guard is admin. Verify a non-admin sees nothing (blank/null), an admin still reaches the page even with the nav link hidden.

### 1.5 Credit-notification settings (Account → Plato AI → Settings)
Same FormSection group as §1.1 — the low-credit alert toggle, the zero-credit alert toggle, and a conditional threshold input. UI-only; do not assert on actual email delivery.
- **Both toggles persist.** Low-credit and zero-credit alert toggles each save (success toast "Plato AI settings saved"), clear dirty state, and survive reload; same unsaved-changes guard as the auto-generate toggle.
- **Threshold is conditional (FormConditionalFields).** The low-credit threshold input appears ONLY while the low-credit toggle is Enabled and disappears when it is set to Disabled.
- **Threshold min + force-to-0 round-trip.** The threshold input enforces min=1; saving with the low-credit toggle Disabled stores 0 and round-trips as 0 through reload.

---

## 2. Auto-Generation (the SILENT path)

Auto-generation has **no completion toast** on success OR failure — verify via the candidate-list status badge / applicant Plato area and the credit balance (Account → Plato AI → Usage), never by expecting a growl.

**Prioritize — each case is a full auto-gen cycle (upload + OCR + AI wall-clock wait); do not run every permutation.**
- **MUST-RUN CORE:** the fire happy path (§2.1) and the silent credit gating (§2.3) — a regression there silently disables auto-review with no error.
- **APPENDIX (only if time / suspected regression):** the exhaustive resume/description gating permutations (§2.4) and the silent-vs-manual distinction (§2.5) beyond one confirming pass.

### 2.1 When it FIRES — new applicant only
- **New applicant, auto resolves ON, org has credits, job has a description, resume present** → row shows in-progress (PlatoHourglass / "Review in progress"), then transitions live (no reload) to a fit score + band on success; exactly one credit consumed (reconcile Usage before/after).
- **Live transition without reload** is the same `ai_summary_status_change` websocket mechanism watched in full at §3.3 — no need to re-run a full live-watch here; just confirm the auto (silent) path updates the list badge/drawer in place.
- **Two applicants in quick succession** each start their own review and consume one credit each — no cross-talk, no double-charge on one applicant.

### 2.2 When it must NOT fire (high-value negatives)
- **Stage move never auto-generates.** Moving an existing candidate between stages (single or bulk) starts no review and consumes no credit — balance unchanged, no new in-progress badge. (Firing is bound to applicant CREATE only.)
- **Existing applicants are not retroactively reviewed** when the toggle is switched on — only applicants created after it is on. Pre-existing candidates stay unscored.

### 2.3 Credit / plan gating (highest-risk silent path)
- **Zero credits → silent no-op.** Org drained to 0 total credits, new applicant on an auto-ON job gets no review and NO error toast — no in-progress badge, balance stays 0. A user could believe auto-review is on while nothing happens.
- **Plan with 0 monthly AI allocation behaves as zero credits** — no add-on/top-up ⇒ no auto-generation, even with the toggle on (plan-tier gating routes through the same credit check).
- **Credits restored → resumes.** After a top-up/subscription grant restores a positive balance, the NEXT new applicant auto-reviews normally, decrementing by exactly one.

### 2.4 Resume / description gating
- **No resume → no auto-review** (silent).
- **Job with no description → no auto-review**, even with auto ON, credits, and a resume. (This is why the Run Plato CTA educates the user to add a description — cross-check in §4.1.)
- **Resume added after applicant creation** (job opted in): a review starts once OCR text is available — verify it fires exactly once, not per edit.
- **DOCX resume auto-reviews** (converts to PDF before OCR) — verify a .docx new applicant is not silently stuck and does eventually score.

### 2.5 Silent vs. manual distinction
- **Auto success fires no toast** — only the in-place status/score update. Do not treat toast-absence as failure.
- **Auto failure is also silent** (no failure growl), whereas a manual generate growls on failure — confirm the two paths stay distinguishable.

---

## 3. Manual Single Generate & Plato Tab Display

**Prioritize — this section has 9 subsections; not all are one-sitting-critical.**
- **MUST-RUN CORE:** the one full single-path live-watch (§3.3 live completion), the succeeded-review render + score-band/criteria core (§3.6/§3.7), and the first-ever-criteria handshake (§3.9 — highest-risk scoring path).
- **APPENDIX (only if time / suspected regression):** exhaustive terminal-state copy (§3.4), every regenerate branch (§3.5), and the sparse/conditional-section spot-checks beyond one confirming pass.

### 3.1 Entry points into the tab
- **Sidebar "Plato" nav item** renders only with the flag ON (`PlatoChip` + "Plato"), routes to `/ai`.
- **Overview header button** reads **Ask Plato** when unreviewed, **View Plato review** when a review exists — both land on the Plato tab; confirm the label reflects state.
- **Activity-feed callout** — a `platoReview` timeline entry's "See full review" chevron lands on the tab (see §3.8).

### 3.2 Ready empty state + generate
Condition: resume present, no prior review, credits > 0.
- Empty state shows "Ask Plato to review this candidate", a **Generate review** button, and footnote **"Uses 1 credit · N remaining"** with the correct live balance.
- **Generate** → tab optimistically switches to the loading animation immediately (no refresh); balance/footnote reflect one credit consumed after refetch.
- **Error path:** a rejected request shows a warning toast (10s) with the server message or "Failed to queue summary"; the tab must fall back to generateable, NOT stick in loading.
- **Bulk-queued variant:** if the candidate is in an in-flight bulk run, the empty state reads "Queued for bulk review" with **Generate review now** (jump-ahead) — verify jump-ahead works and doesn't visibly double-charge.

### 3.3 In-flight / generating state (`PlatoLoadingState`)
- Renders header "Plato is reviewing this candidate" + 4 steps (Processing the resume / Analyzing the candidate / Scoring against the role / Finalizing the review).
- **Step progression** maps to backend status and only moves **forward** — verify it never regresses as statuses advance (watch a live generation or a bulk-queued auto-generation via websocket).
- After **~10s**, the "You can keep working — Plato will finish in the background." line appears.
- **Reduced motion:** with OS reduce-motion on, the active-step spinner does not animate.
- **Live completion (key regression risk — the one full single-path live-watch; §2.1/§3.5 cross-reference this):** without touching the page, finishing auto-transitions to the succeeded review (websocket `ai_summary_status_change`). Watch for the tab hanging in loading until a manual refresh.
- **Global completion toast (navigate-away payoff — the GlobalChannel `AI_SUMMARY_COMPLETE` surface, distinct from the on-tab live transition above; parallels the bulk case in §4.5):** while a manual single generate is running, navigate AWAY from the candidate; on completion a global success/warning toast appears (~10s) whose link routes back to the correct candidate. This is the payoff of the "keep working — Plato will finish in the background" promise for the single-send path. Auto-generation fires no such toast (§2.1/§2.5).

### 3.4 Terminal / non-generating states
- **Failed:** shows "Plato couldn't analyze this candidate… No credit was used" + **Try again** — verify Try again re-runs generation and the no-credit-used copy is accurate.
- **No resume:** `none` status → "Plato needs a resume" + **Go to resume tab** navigating to the candidate's `/resume` tab.
- **No credits (admin):** balance ≤ 0 → "You're out of Plato credits" + working **Buy credits** → `/hire/settings/plato-ai/billing`.
- **No credits (non-admin):** same title, member copy ("Ask an admin…"), **Buy credits disabled** — no purchase path.
- **Credit-balance query error → treated as 0 remaining** (code-verified — a React Query error isn't inducible from the UI; skip in a manual pass): a failed balance query degrades to the no-credits path (generation blocked), not a doomed generate.

### 3.5 Regenerate (stale review)
Condition: `statusValue === "current"` AND the summary is stale (résumé changed). Control lives header-right.
- **Credits > 0:** **Regenerate** button → confirmation modal "Are you sure you want to regenerate?" with "Uses 1 credit of **N** remaining" (N matches live balance). Confirm → runs (§3.3) with the prior review still visible underneath; Cancel → no-op.
- **Double-click guard:** Regenerate is loading/disabled while credits load or a generation is in flight — rapid clicks cannot queue two.
- **Stale + out of credits (admin):** Regenerate replaced by a **Buy credits** link → billing.
- **Stale + out of credits (non-admin):** **Buy credits** opens an "Admin access required" modal — no purchase path.
- **Regenerating chip:** while `regenerating`, header-right shows a spinning sparkle chip + "Regenerating" with the prior review still rendered below. The live completion transition is the §3.3 websocket mechanism — don't re-run a full live-watch; just watch for no flicker/flash on the transition into regenerating or into failure.
- **Non-stale review:** header-right shows nothing — a fresh review surfaces no Regenerate CTA.

### 3.6 Succeeded review rendering (`PlatoSummary`)
Condition: `current`/`regenerating` with the full summary loaded.
- **Meta line** "Generated by Plato · <relative time>" from the status row `updatedAt`.
- **Stale banner** shows only when stale.
- **Score row:** `PlatoScoreTag` band label + 0–5 fit sparkles, both driven by `scorePercentage` (see §3.7).
- **Headline**, **Domains** (primary + secondary, dot-separated, capitalized; block hides when none).
- **"Fit for this role":** prose from `integratedRoleAnalysis` → `structuredData.roleAnalysis` → `summaryText`; block hides when all three empty.
- **Scoring detail accordion** (§3.7), **Notable achievement(s)** (singular/plural heading), **Relevant experience**, **Open questions** — each renders only when its field is present.
- **Skills chips:** key skills sort to the front and are styled distinctly (`KeySkillChip` vs `SkillChip`, case-insensitive match) — verify key skills lead and NO React key/DOM-prop console warnings.
- **Conditional-section rule:** spot-check a sparse review (no gaps/achievements) renders cleanly — no empty headers or stray separators. Disclaimer footer always present.

### 3.7 Score → fit band & criteria breakdown
- **Band thresholds** (verify a real candidate's `scorePercentage` lands in the expected label + star fill):
  - ≥90 → Excellent (5★, linear tag) · ≥60 → Good (4★, linear) · ≥35 → Mixed (3★, light) · ≥15 → Weak (2★, light) · 0–14 → Poor (1★, light). The score row always shows at least 1 filled sparkle (star count comes from `band.fill`, min 1, not the raw percentage).
- **Scoring detail accordion:** groups into Core (tier_1) / Preferred (tier_2) / Bonus (tier_3); empty tiers dropped. Rows sort full_match → partial_match → not_found (`not_found` greyed). Header shows "N criteria" + met/partial/missing tally — verify the tally equals row counts and criterionText/reasoning render (not blank) on expand.

### 3.8 List fit indicator & activity-feed callout (shared surfaces)
- **List row fit indicator:** scored candidates (`current`/`regenerating` with a score) show a `FitHarvey` swatch + band label; `initial_summary_pending`/`bulkAiSummaryProcessing` show a `PlatoHourglass` "Review in progress"; unscored rows show neither. Harvey fill tier roughly tracks the band.
- **Activity-feed callout:** a reviewed candidate shows a `platoReview` timeline entry (headline, role-fit prose clamped to 4 lines, score tag + stars, "Generated by Plato · <ago>"); "See full review" → the Plato tab. Regression: the rest of the feed (comments, reviews, stage changes) renders normally for candidates WITH and WITHOUT a review — no broken connector/order around the callout.

### 3.9 First-ever criteria extraction & the awaiting_job_criteria handshake (highest-risk scoring path)
Condition: a freshly published job that has a description but NO prior AI criteria (never scored), then generate the first-ever review on a candidate there. This is the only setup that exercises criteria extraction firing and the `awaiting_job_criteria` → resume handshake — every §3.7 case skips it by using jobs whose criteria already exist. If the after-commit extraction trigger regresses, the summary stalls in `awaiting_job_criteria` forever.
- **Extraction fires and the summary resumes.** The loading state passes through "Scoring against the role" (the `awaiting_job_criteria` step, §3.3) and then resolves to a completed review — NOT stuck in that step. The Scoring detail accordion (§3.7) is populated with Core/Preferred/Bonus rows, proving criteria were extracted and the summary re-enqueued once they succeeded.
- **Re-extraction on a meaningful description change (optional):** after a substantive edit to the job description, a re-scored candidate reflects re-extracted criteria (allow the ~30s debounce). A trivial/whitespace-only edit does NOT re-extract.

---

## 4. Bulk Generate

Two entry points: **Whole-job** (job stages sidebar → "Run Plato" CTA card → "Review all candidates" modal) and **Per-stage** (stage candidate list → tick checkboxes → Bulk options → Generate AI summaries → confirm modal). Both flag-gated. "Already scored" = row shows a fit swatch (`current`).

**Prioritize — bulk runs are multi-page and finish async; do not exhaust every count/plural branch.**
- **MUST-RUN CORE:** both entry points' happy paths (§4.1 Review-all modal opens with a real count, §4.3 mixed per-stage selection) and async completion + email (§4.5).
- **APPENDIX (only if time / suspected regression):** exhaustive count and singular/plural branches (§4.2/§4.3), the shortfall permutations (§4.4), and the filter-interaction branches (§4.6) beyond one confirming run.

### 4.1 Whole-job CTA routing gates (precedence: description → no-candidates → review-all)
- **No job description → Add-description modal**, even with zero candidates (description gate wins); "Edit job description" links into Job Setup; no API call.
- **Description + 0 candidates → No-candidates modal.** Two layouts: auto-generate ON (single "write a specific description" tip) vs OFF (two-step, links to org Plato AI settings and this job's `/setup/ai`).
- **Description + candidates > 0 → Review-all modal** opens (no API call until confirm).

### 4.2 Whole-job "Review all candidates" modal — count & rescore
Count = `rescore ? total : max(total − alreadyReviewed, 0)`.
- **Rescore OFF counts only un-reviewed** — body count = all − already-reviewed, with correct singular/plural "doesn't/don't have a Plato review yet" copy.
- **Rescore ON re-includes reviewed** — ticking jumps the count to the full total and recomputes the credit line.
- **All reviewed + rescore OFF → count 0 → "Review all" disabled**; ticking rescore re-enables.
- Emphasized "uses up to N credits from your balance of X available" matches live count and balance.

### 4.3 Per-stage confirm modal — selection modes (always excludes already-scored, no rescore)
`processableCount` = selection size − loaded candidates at `current`.
- **No selection → "No candidates selected."**, Generate disabled.
- **Every picked candidate already reviewed → "Nothing to generate…"**, Generate disabled.
- **Mixed selection, all rows loaded (exact):** "Generate AI summaries for N candidate(s)… N credit(s)… balance of X", N excluding already-scored rows.
- **Select-All where rows are NOT all loaded (inexact):** copy switches to "for up to N… using up to N credit(s)" and the **Caveat block** appears — verify via Select-All on a stage larger than one page (scroll not exhausted).
- **Select-All-minus-exclusions:** deselect a few after Select-All; count = selectable − excluded − already-scored-loaded. Verify singular/plural in every branch.

### 4.4 Credit balance & shortfall (both modals)
`shortfall = max(0, needed − available)`, shown only when shortfall > 0 AND needed > 0.
- **Needed > available → shortfall banner** "You are short N… first {available} get summaries; the rest skipped" — verify numbers/plurals; submit is still allowed (partial run).
- **Zero available → submit blocked by validation** ("no credits available — purchase credits…"), no POST — distinct from the shortfall case (which does POST).
- **Balance query error → treated as 0 available** (code-verified — not inducible from the UI; skip in a manual pass): a failed balance query takes the zero-credit path (validation blocks), not a real balance.

### 4.5 Submit toast + async completion
- **Confirm toast** composed from queued / skipped / textract-pending fragments, joined by ". "; each fragment appears only when non-zero. **All zero → "No summaries to generate".** Skip = no resume or already processing (already-reviewed dropped silently, not counted as skipped). Failure → warning toast (10s).
- **Per-stage only:** on success the selection clears (checkboxes reset); the whole-job modal does not clear a list.
- **Double-submit guard:** button loads/disables during the request — a fast double-click cannot fire two POSTs.
- **Async completion (the one bulk-path live-watch + completion email):** a live completion toast (websocket) eventually appears for the acting user without reload; a result **email** arrives (subject "Your Plato reviews for {job title} are ready" or the failure variant). Candidate rows refetch after completion — reviewed rows gain swatches, in-progress rows show the hourglass, no manual reload.

### 4.6 Role-fit filter interaction (regression-sensitive)
Select-All resolves server-side against the applied "Filter by fit".
- **Filter applied + Select-All + Generate → only the filtered band is processed** (minus deselected, minus already-reviewed) — verify count and acted-on set match the visible filtered set.
- **No filter → whole-stage behavior unchanged** (empty roleFit drops no one).
- **Changing stage resets filters** — a Select-All right after a stage switch acts on the full unfiltered stage.

### 4.7 Flag & menu visibility
- **"Generate AI summaries"** appears in Bulk options only with the flag ON (flag OFF → only Message/Move).
- **"Run Plato" CTA card** renders only with the flag ON, at the bottom of the job stages sidebar.
- **Bulk menu appears only when the stage has candidates** (empty stage → no bulk menu).

---

## 5. AI Credits Billing UI

Surfaces: **Billing** `/hire/settings/plato-ai/billing`, **Usage** `/hire/settings/plato-ai/usage`, and the **Plan & billing** handoff callout. Admin-only, flag-gated nav (see §1.4). Stripe-hosted flows leave the app — verify the redirect and correct return landing; do not QA Stripe's own pages.

**Prioritize — this section is long; one sitting need not run every branch.**
- **MUST-RUN CORE (high-value / high-risk):** subscribe an unsubscribed org (§5.4); ONE change direction — upgrade OR downgrade (§5.5); cancel (§5.7 cancel); one-off top-up with a card on file (§5.8 card path); plus credit gating (§2–§4) and live completion (§3.3, §4.5), already covered there.
- **APPENDIX (optional — only if time or a suspected regression):** the remaining lifecycle branches (§5.6 scheduled-change callout, §5.7 revert, the second change direction, §5.9 usage detail) and all exact-copy verification. Treat every copy check as "correct plan name / count / date shown + correct outcome toast fires," not verbatim string matching.

### 5.1 Access & handoff
- **Handoff callout placement:** "AI credits — Manage AI credits" card shows at the bottom of Plan & billing on both subscribed and unsubscribed plan pages, but **NOT** on the free-trial page; clicking it navigates to the Billing page.
- **Plan feature availability (NOT plan-gated):** AI applicant summary is a universal plan feature available on every plan — free and no-plan orgs included (they receive a monthly AI credit allocation). AI surfaces and the handoff callout are gated ONLY by the `AI_APPLICANT_SUMMARY` Flipper flag, never by plan tier — so on a free/no-plan org with the flag ON, AI + the callout are PRESENT. For a gating check, toggle the Flipper flag ON vs OFF (§1.4), not paid vs free plan.

### 5.2 Page load & Stripe-return refresh
- **Initial load:** full-page spinner while prices fetch, then status banner + subscription tiers + one-off cards — no flash of empty cards.
- **Return from checkout:** returning with `?ai_credit_subscribe_success` or `?ai_credit_top_up_success` refreshes balance/subscription/purchase data (once, on mount) without manual reload; a plain visit with no such param must NOT force a refetch.

### 5.3 Subscription status banner states
- **Unsubscribed:** banner shows the no-subscription state + a subscribe prompt + "Manage billing".
- **Active:** banner shows the active state with the correct plan name, credits-per-month count, and a real formatted renewal date (roll-over note) matching the subscribed tier.
- **Scheduled to cancel:** banner shows the scheduled-cancel state with the correct date; the button swaps to **"Don't cancel subscription"** (Manage billing hidden).
- **Not manually reproducible (code-verified — skip):** `past_due` also renders as subscribed (needs a failed Stripe renewal / test clock); a missing period-end falls back to "next period", never blank or `Invalid Date`.

### 5.4 Start a subscription (unsubscribed org)
- **Subscribe** on each tier goes straight to Stripe Checkout redirect (no in-app confirm modal) — verify the redirect.
- **Subscribe error →** toast "Unable to start subscription.", user stays on the page.
- **Section subtitle** reads "Choose a credit subscription" when unsubscribed.

### 5.5 Change plan — upgrade / downgrade (active org)
Core: run ONE direction (upgrade OR downgrade); the other is appendix.
- **Button text per tier:** higher-credit → "Upgrade" (primary), lower → "Downgrade" (secondary), equal → "Change plan" (secondary); the current tier shows a "Current plan" badge + "Cancel". `_large` tier shows "Best value" unless it is the current plan.
- **Preview → confirm modal:** the change previews first, then opens the confirm modal; preview failure → error toast and no modal.
- **Modal correctness:** the confirm modal shows the correct new plan name, credits/month, and (upgrade) a prorated amount-due-today or (downgrade) the scheduled end-of-period date + the "then {N} instead of {M}" credit counts — all matching the selected tier and the real current plan. Confirm → the correct outcome toast fires (upgrade succeeded / change scheduled); commit error → error toast.

### 5.6 Scheduled change callout (appendix — optional)
- **After a downgrade:** a callout above the tiers names the correct from/to plans and date.
- **Cancel the schedule:** "Don't downgrade plan" → callout disappears, plan stays current, correct outcome toast fires; button disables while in-flight.

### 5.7 Cancel & revert
- **Cancel (core):** the cancel confirm modal explains it stops renewing, keeps existing credits, no further charge, and shows the correct "will not renew" date (matches period end). Confirm → correct outcome toast, banner → scheduled-to-cancel (credits retained).
- **Revert (appendix — optional):** from scheduled-to-cancel, "Don't cancel subscription" → correct outcome toast, banner returns to normal active/renews.

### 5.8 One-off top-up purchase (forks on default payment method)
- **Card on file → confirm modal** "Confirm your purchase" (credit count, "Amount due today", payment-method label). Confirm → direct charge. **No in-app success toast on this path** (success is server/websocket) — verify the modal closes and the balance updates, do not expect a toast.
- **No card on file → straight to Stripe Checkout** (skips modal); returning with `?ai_credit_top_up_success` refreshes the balance (§5.2).
- **Preview error (card) →** toast "Unable to load purchase preview.", no modal. **Checkout-session error (no card) →** toast "Failed to create checkout session".
- **Card contents:** dollar price, credit count, "one-time" label; numbers match configured packs; copy states credits are immediate and roll over.

### 5.9 Usage tab balance display (appendix — optional)
- **Balance breakdown:** segmented bar + three rows — Monthly plan credits (reset, do NOT roll over), Subscription credits (reset, roll over), Top-up credits (roll over, spent last). Each row's remaining count + reset date correct.
- **Total + Buy credits:** total row shows the credits-total; Buy credits → billing page. Spend-order intro copy (monthly → subscription → top-up) matches the row order.
- **Zero-balance:** all buckets 0 → 0 total, every row 0, bar renders empty (no divide-by-zero artifact / stray filled segment).
- **Large numbers** comma-formatted (e.g. `2,500`) in rows and total.

### 5.10 Double-click / loading guards (highest-risk double-submit path)
- **Tier buttons** disable while any subscription mutation (subscribe/preview/commit) is in flight and show a loading state while the subscription refetches — rapid clicks must not fire duplicate previews/commits.
- **One-off Buy** disables/loads while a purchase is in flight.
- **Confirm modals** (subscription-change and top-up) dismiss the moment Confirm is clicked (before the charge fires) — a fast double-click on Confirm cannot fire two charges/changes.
- **Scheduled-change cancel** button disables while its cancel is in flight.

---

## 6. Non-AI Regression Spot-Checks

NOT the AI feature itself — spot-check EXISTING behavior running through code the AI work rewrote. Baseline to protect: **flag-OFF org, NO fit filter, normal plan** must behave exactly as production. Turn the flag OFF where a case says so.

**Prioritize — protect the shared surfaces most likely to break; skip the finer per-item audits if pressed.**
- **MUST-RUN CORE:** the plan-picker upgrade/downgrade and Manage billing (§6.1), applicant intake PDF + DOCX (§6.2), the no-filter list/bulk no-op (§6.3), and org signup (§6.6) — the highest-traffic regressions.
- **APPENDIX (only if time / suspected regression):** the finer per-item checks (§6.4 hiring-document relocation, §6.5 left-nav/layout) and the count-drift edge cases beyond one confirming pass.

### 6.1 Billing & Stripe plan flow (plan-picker + webhook rewritten)
The `customer_subscription` plan-picker now filters out any credit/plato subscription before choosing the plan; every org's plan detection routes through it.
- **Real plan upgrade AND downgrade** through normal Plan & billing → new plan resolves correctly (name, limits, features). Highest-value case — a mismatched subscription id could silently skip the plan update.
- **Trial → active** lands on the correct paid plan; **free_plan** org still shows free (not mis-detected).
- **WWR / WhatJobs listing purchase** → the job publishes / listing activates on payment (webhook listing branches refactored to early returns).
- **Org with vs. without a subscription** both behave sanely on the billing page (the moved `invoice.paid` guard changed which orgs hit it).
- **Manage billing (SHARED regression):** from the STANDARD non-AI Plan & billing page, "Manage billing" opens the Stripe portal and returns to `/hire/settings/billing`; from Plato AI pages it returns to the Plato AI billing page; a failed portal-session → toast "Unable to access billing portal." The promo-code ("Use promo code") dropdown still appears where it did (active subscription without coupon). This is the top regression risk in the billing slice (portal call moved from a parent callback to an internal mutation).

### 6.2 Applicant intake & resume OCR (flag OFF) — highest-traffic path
`enqueue_new_job_application` and Textract were modified; docx now converts to PDF before OCR, prior TextractResults are retained.
- **Apply with a PDF resume** → applicant created, appears in list, resume + extracted text available.
- **Apply with a DOCX resume** → same result (not stuck), resume/text lands.
- **Re-upload a resume on an existing candidate** → OCR re-runs, newest resume/text wins (older results retained but the candidate shows the latest, not stale).
- **Bulk candidate import** still succeeds at scale (each new applicant now also creates a companion status row + extra sync work — no failures/slowdowns).
- **Public apply flow** creates the candidate normally in a flag-OFF org.

### 6.3 Candidate list & bulk actions, NO fit filter (must be a no-op)
List query, bulk move, and bulk message now route through `apply_role_fit_filter`/`roleFit`.
- **List result set unchanged** with no filter — same candidates, order, pagination as production; the (non-gated) "Filter by fit" dropdown's mere presence must not alter the default list.
- **Bulk move / bulk message, no filter:** select-all and select-all-minus-exclusions target the same set as production; move success toast + `bulk_move_completed` count correct (count now from server `movedCount`); recipient set identical to production.
- **Selection-count math** on the stage menu matches the visible list (count source changed to `selectableCount ?? stage count`), including on a stale/loading list.
- **Stage live updates:** moving/editing a candidate refreshes the list normally, no double-loading (mutations now also invalidate AI-summary cache keys).

### 6.4 Hiring-document relocation & candidate overflow menu
The "Overview options" dropdown on the candidate Overview header was REMOVED; Add/Edit hiring document moved to the sidebar actions menu.
- **Add/Edit hiring document reachable (flag OFF)** in the sidebar actions/overflow menu and opens the document modal — confirm nothing else from the removed Overview-options menu was lost; the **`H` hotkey** still opens it.
- **Candidate overflow menu** (renamed testid) — other actions still fire.
- **Activity timeline intact** for a candidate with no AI review (a new feed entry type was injected) — no blank/broken timeline.

### 6.5 Left-nav & global page layout (shared across every page)
- **Left-nav across ALL items** (the icon-reveal selector was restructured for every item): each item renders its chevron/count, hover reveals the trailing icon, active-item styling intact — check non-AI items (Jobs, Candidates, etc.).
- **Both app layouts load clean** (hiring app + account/job-board app) — no blank/broken areas. A new inline `window` global was added to the shared globals script; confirm dependent globals still work — recaptcha renders on auth pages and an embedded job board loads.
- **Account tabs (flag OFF)** — Users, Templates, API keys, Plan & billing all render/navigate; the Plato AI tab is absent.
- **Job Setup tabs (flag OFF)** — existing routes load and the job-description sidebar layout looks correct (a sidebar CSS change applies unconditionally); no Plato tab.

### 6.6 Org lifecycle & plan gating
- **Org signup / creation** succeeds end to end (a synchronous AI-credit-state creation now runs inside the org-creation transaction — confirm signup doesn't fail/hang).
- **Org deletion (god-admin)** — deleting an org still succeeds (or fails cleanly/as-expected) now that every org has an AI-credit-balance row with `dependent: :restrict_with_error`; confirm the new AI associations don't block org teardown.
- **Org settings save** round-trips existing non-AI settings correctly (new AI keys added to the shared payload — nothing existing clobbered).
- **Plan limits still enforced** — hit a plan's `job_limit` / `user_limit` and denied-feature gate; fires exactly as production (new AI keys merged into `plan_rules` must not have shifted these).
- **Non-admin job edit still saves** a normal job update (the new authorization branch is only for the AI auto-generate key — see §1.3).
- **Job counts accurate** — job list/detail counts (new counter-cache columns) are correct and don't drift after adding/removing applicants.
