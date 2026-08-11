# Plato AI — Manual QA: Single Generate & Display

Area: manual single-generate from a candidate + the Plato tab (display, state machine, regenerate, score/headline/analysis rendering).

**Preconditions for all cases:** org has the `AI_APPLICANT_SUMMARY` flag ON and (unless a case says "0 credits") a positive AI credit balance. Reach the tab from a candidate drawer → **Plato** nav item in the sidebar. It's also reachable from the Overview header **Ask Plato / View Plato review** button and the activity-feed **See full review** callout — both push to the `/ai` tab.

The tab's whole render is gated by the status row (`aiJobApplicationSummaryStatus.status` = none/initial_summary_pending/current/regenerating) plus the loaded full summary's finer status (pending → textract_processing → extracting → summarizing → awaiting_job_criteria → scoring → integrating → succeeded | retrying | failed). Most defects here are a state landing on the wrong panel or not transitioning live.

---

## 1. Entry points & tab visibility

- **Sidebar Plato nav item** — renders (PlatoChip + "Plato") only with the flag ON; routes to `/ai`. Verify it's absent for a flag-OFF org and that the `/ai` route still mounts if hit directly.
- **Overview header button** (`PlatoCtaButton`) — label is **Ask Plato** for an unreviewed candidate, **View Plato review** once a review exists. Verify the label reflects review state and lands on the tab.
- **Header row** — left is always PlatoChip + "Plato"; a bottom border appears **only when content is present** (`current`/`regenerating`). Verify no border on empty/loading/failed states.

## 2. Manual single generate — "ready" empty state

Condition: candidate has a resume, no prior review, credits > 0.

- Copy check: title **"Ask Plato to review this candidate"**, **Generate review** button, footnote **"Uses 1 credit · N remaining"** with the correct live balance.
- Click **Generate review** → tab switches **optimistically** to the loading animation (§3) with no manual refresh; balance footnote decrements by one after the credit query refetches.
- **Error path:** a rejected generate shows a warning toast (10s) with the server message (`errors.general[0]`) or fallback **"Failed to queue summary"**; the tab must NOT stick in loading — it falls back to a generateable state.
- **Bulk-queued variant** (`bulkAiSummaryProcessing` true): empty state instead reads **"Queued for bulk review"** with a **Generate review now** jump-ahead button. Verify the jump-ahead generate fires and doesn't visibly double-charge.

## 3. In-flight / generating state (loading animation)

Condition: any of pending / textract_processing / extracting / summarizing / awaiting_job_criteria / scoring / integrating / retrying / succeeded-without-structuredData, OR the local optimistic `showPlatoLoading` flag.

- `PlatoLoadingState` renders: heading **"Plato is reviewing this candidate"**, subcopy "Reviewing role fit, relevant experience, skills, and gaps.", and the 4 steps: **Processing the resume / Analyzing the candidate / Scoring against the role / Finalizing the review**.
- **Step progression** (status → active step): textract_processing → step 1; extracting/summarizing → step 2; awaiting_job_criteria/scoring → step 3; integrating → step 4. `pending`/unmapped → step 1. The active step **only moves forward** (`Math.max`) — verify it never regresses as statuses advance (watch a real generation progress live).
- After **~10s** the line **"You can keep working — Plato will finish in the background."** appears.
- **Reduced motion:** with OS reduce-motion on, the active-step spinner should not animate.
- **Live completion (highest risk):** without touching the page, the tab must auto-transition to the succeeded review (§6) when generation finishes — this is websocket-driven (`ai_summary_status_change` / `AI_SUMMARY_COMPLETE`). The regression to watch: the tab hangs in loading until a manual refresh.

## 4. Terminal / non-generating states

- **Failed:** full-summary status `failed` → title **"Plato couldn't analyze this candidate"**, message asserting **"No credit was used"**, and a **Try again** button (refresh-cw icon). Verify Try again re-runs generation (→ §3) and that the no-credit-used claim is truthful.
- **No resume:** status none + no résumé → **"Plato needs a resume"** with **Go to resume tab**. Verify the button swaps the last URL segment to `/resume` and lands on the candidate's resume tab.
- **No credits (admin):** balance ≤ 0 → **"You're out of Plato credits"**, admin copy ("Purchase more credits…"), and a working **Buy credits** button linking to `/hire/settings/plato-ai/billing`. Verify the live route resolves. (The orphaned `AiSummaryState` uses a different `/hire/settings/ai-billing` — do not test that path.)
- **No credits (non-admin):** same title, member copy ("Ask an admin…"), **Buy credits** button is **disabled**. Verify a member cannot initiate purchase from the tab.
- **Credit-balance query error:** a balance-load error is treated as 0 remaining → the no-credits path fires (generation blocked). Verify the tab degrades to no-credits rather than offering a generate that would fail.

## 5. Regenerate (stale review)

Condition: status `current` AND the loaded summary is **stale** (résumé/description changed since the review). The control lives in the header-right.

- **Credits > 0:** header-right shows a **Regenerate** text button (refresh icon). Click → confirmation modal **"Are you sure you want to regenerate?"** with subcopy including **"Uses 1 credit of N remaining"** (verify N = live balance). Confirm → generation runs (§3) with the **prior review staying visible underneath**; Cancel → no-op.
- **Double-click guard:** the Regenerate button is `loading`/`disabled` while credits load or a generation is in flight — verify rapid clicks cannot queue two regenerations.
- **Stale + out of credits (admin):** Regenerate is replaced by a **Buy credits** link → `/hire/settings/plato-ai/billing`.
- **Stale + out of credits (non-admin):** **Buy credits** button opens an **"Admin access required"** center modal (contact-an-admin copy, Close button). Verify no purchase path for members.
- **Regenerating chip:** while status `regenerating`, header-right shows a **spinning sparkle chip + "Regenerating"** and the previously generated review stays rendered below. Watch the transition into `regenerating` and into `failed` for flicker/flash — the optimistic-loading flag is cleared via a setState-during-render, so verify no visible double-render on those transitions.
- **Non-stale review:** header-right shows **nothing**. Confirm a fresh, non-stale review offers no Regenerate CTA.

## 6. Succeeded review rendering (`PlatoSummary`)

Condition: `current` (or `regenerating`) with the full summary loaded.

- **Meta line:** "Generated by Plato · <relative time>" from the status row `updatedAt`.
- **Stale banner:** shows only when stale ("The resume has changed since this review was generated. Regenerate to update.").
- **Score row:** a `PlatoScoreTag` (band label) + a row of fit sparkles. See §7 for the band/star mapping (the star count comes from the band, not the raw %).
- **Headline** from the status row headline.
- **Domains:** primary + secondary domain, dot-separated, first-letter uppercased. Block hides when there are no domains; a single domain shows no dot.
- **"Fit for this role" block:** prose sourced from `integratedRoleAnalysis` → falls back to `structuredData.roleAnalysis` → then `summaryText`. Verify content appears and the whole block hides only when all three are empty.
- **Scoring detail accordion** — see §7.
- **Notable achievement(s):** award-icon list; heading is singular/plural by count. Hidden when empty.
- **Relevant experience** and **Open questions** (gaps): each renders only when its field is present.
- **Skills chips:** key skills sorted to the front and styled distinctly (`KeySkillChip` filled vs `SkillChip` outlined); membership match is case-insensitive against `keySkills`. Verify key skills lead visually and there are **no React key / unknown-DOM-prop console warnings** (separate styled variants, not a boolean prop).
- **Disclaimer footer** ("Generated by Plato — always confirm against the resume before deciding.") is always present.
- **Conditional-section rule (high value):** every section hides when its data is absent. Spot-check a **sparse** review (e.g. no gaps, no achievements, no domains, empty criteria) renders cleanly — no empty eyebrows, no stray separators, no orphaned score row.

## 7. Score → fit band & criteria breakdown

- **Band thresholds** (`pct >= threshold`, first match wins): ≥90 Excellent, ≥60 Good, ≥35 Mixed, ≥15 Weak, else (0–14) Poor. Verify a candidate's numeric score lands in the expected **label**.
- **Boundary values** 90 / 60 / 35 / 15 map to the **higher** band — verify each boundary exactly.
- **Star count is driven by the BAND, not the percentage** (this is the gotcha): Excellent 5★ / Good 4★ / Mixed 3★ / Weak 2★ / Poor 1★. There is **no 0-star state** — a rendered review always shows 1–5 filled sparkles, and a **0% score shows the Poor band with 1 star** (do not expect 0 filled). Verify the star count matches the band, not the raw number.
- **Tag style:** Excellent & Good use the gradient ("linear") tag; Mixed/Weak/Poor use the outlined ("light") tag. Verify the two visual treatments split at the Good/Mixed boundary.
- **Scoring detail accordion:** title "Scoring detail", count "N criteria" (N = total rows), header tally of met/partial/missing marks + counts. Groups into **Core (tier_1) / Preferred (tier_2) / Bonus (tier_3)**; **empty tiers are dropped**. Within a tier rows sort full_match → partial_match → not_found. `not_found` rows render **greyed** (both criterion text and reasoning). Expand a row → reasoning shows. Verify: the tally counts equal the actual row counts, section counts equal their row counts, and `criterionText`/`reasoning` render (serializer field-name match — not blank).

## 8. Activity-feed Plato callout (shared display surface — regression)

Condition: reviewed candidate (`current`/`regenerating`), viewing the candidate Overview/activity feed.

- A `platoReview` entry (`PlatoGeneratedReviewCallout`) is injected into the timeline, sorted by its published time, rendering: "Generated by Plato · <ago>", headline, role-fit prose **line-clamped to 4 lines**, and the band tag + stars (same band/star mapping as §7).
- **See full review** (chevron) navigates to the Plato tab.
- **Regression check:** the rest of the activity feed must render normally for candidates **with and without** a Plato review — non-AI items (comments, reviews, stage changes) unaffected, and the timeline connector/order not broken around the injected callout.
- Note: the Overview header's old "Overview options" menu was removed and replaced by the Plato button. Confirm the hiring-document add/edit action still exists (relocated to the sidebar actions dropdown, `H` hotkey) — deeper coverage of that relocation lives in the regression guide.

## 9. Cross-reference (owned by other slices — light spot-check only)

- **Per-candidate list fit indicator** (`JobApplicationNavItem`): scored rows (`current`/`regenerating` + score) show a `FitHarvey` swatch + band label; `initial_summary_pending` or `bulkAiSummaryProcessing` show a `PlatoHourglass` ("Review in progress"); otherwise nothing. Harvey fill tier tracks the band (weak/mod/strong). Full list/filter coverage → `qa-regression.md` / list slice.

---

**Not in scope here (other slices):** bulk-generate modals & Run-Plato CTA cards (`qa-bulk-generate.md`), auto-generation firing/gating (`qa-auto-generate.md`), account billing/settings pages (`qa-billing-credits-ui.md`), the filter-by-fit dropdown, and all backend pipeline behavior. Shared surfaces are referenced only where they render this area's display.
