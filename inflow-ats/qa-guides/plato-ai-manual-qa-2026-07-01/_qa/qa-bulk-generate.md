# QA — Bulk generate AI summaries (across candidates)

Two distinct bulk entry points, both behind the `AI_APPLICANT_SUMMARY` flag:

- **Whole-job / all-stages** — job stages view → "Run Plato" CTA card → `Run Plato` → routes to the **Review all candidates** modal (server processes every application on the job). `POST /bulk_ai_job_application_summaries/all_stages`.
- **Per-stage selection** — a stage's candidate list → tick candidate checkboxes (or the stage-name checkbox for Select-All) → `Bulk options` → `Generate AI summaries` → the **Generate AI summaries** confirm modal. `POST /bulk_ai_job_application_summaries`.

Convention below: "already scored / has a review" = the row shows a fit swatch (status `current`); "no review yet" = no swatch (or the in-progress hourglass). The whole-job modal has a **rescore** option; the per-stage modal does **not** (already-scored are always excluded there).

---

## 1. Whole-job CTA routing gates (all-stages entry only)

The `Run Plato` button opens ONE of three modals; verify the precedence order **description → no-candidates → review-all** (earlier gate wins).

- **No job description → Add-description modal**, even when the job ALSO has zero candidates (description gate beats the no-candidates gate). `Edit job description` deep-links to Job Setup → description. No POST fires.
- **Description present + 0 candidates → No-candidates modal.** Verify BOTH layouts branch on the job's auto-generate state: auto ON = single "write a specific description" tip; auto OFF = two-step layout with links to org Plato AI settings and this job's `/setup/ai`. No POST.
- **Description present + candidates > 0 → Review-all modal.** No POST until you confirm.

## 2. Whole-job "Review all candidates" modal — count math & rescore

Count = `rescore ? totalCandidates : max(totalCandidates − existingSummaryCount, 0)`.

- **Rescore OFF (default) counts only un-reviewed candidates.** On a job with some already-reviewed candidates, the body count = all − already-reviewed; verify the "N candidate(s) … doesn't/don't have a Plato review yet" singular/plural is correct at count 1 vs N.
- **Rescore ON re-includes already-reviewed.** Ticking "Also re-review candidates that already have a review" jumps the count to the full total and recomputes the credit line.
- **All candidates already reviewed + rescore OFF → count 0 → `Review all` disabled;** ticking rescore re-enables it.
- **Credit line** "uses up to N credits from your balance of X available" must match the live count and the current org balance at open time.
- Zero-candidate jobs never land here (routed to the no-candidates modal in §1).

## 3. Per-stage confirm modal — selection modes + INCLUDE vs EXCLUDE already-scored

`processableCount` = the selection minus **loaded** rows already at `current`. Already-scored candidates are NEVER re-processed on this path (no rescore option). Verify the four instruction branches:

- **No selection (candidatesCount 0):** "No candidates selected." guidance; `Generate` disabled.
- **Selection where every picked candidate already has a review (processableCount 0):** "Nothing to generate. Every selected candidate already has an AI summary…"; `Generate` disabled.
- **Mixed selection, all rows loaded (exact):** "Generate AI summaries for N candidate(s). This will use N credit(s) from your balance of X available." N must EXCLUDE the already-scored rows within the selection.
- **Select-All on a stage whose rows are NOT fully loaded (inexact):** copy switches to "for up to N … using up to N credit(s)" AND the **Caveat block** appears ("This is a Select All and not all candidates are loaded, so this may be an overestimate…"). Reproduce by Select-All on a stage larger than one loaded page.
- **Select-All-minus-exclusions:** deselect rows after Select-All → count = stageSelectableCount − excluded, then further minus already-scored loaded rows.
- Singular/plural correctness in every branch; verify the standing help text listing skip reasons (no resume / resume needed processing / already processing) renders.

## 4. INCLUDE vs EXCLUDE already-scored — where the two paths diverge (high value)

This is the core behavioral split; verify against a job/stage that has a MIX of scored and unscored candidates.

- **Per-stage always EXCLUDES already-scored.** Already-`current` candidates in the selection are dropped at enqueue and are **not** even reported as skipped (they silently vanish from the count). Confirm only the unscored subset is queued and charged.
- **Whole-job EXCLUDES already-scored by default, INCLUDES them only with rescore ON.** With rescore OFF, already-reviewed are dropped (and not reported); with rescore ON they are re-queued and re-charged. Verify a rescored candidate actually regenerates (prior review stays visible during regen, then updates).
- **Double-charge guard:** confirm re-running the same bulk action while a batch is mid-flight does NOT re-queue candidates already `processing` in another batch — they are dropped (counted as skipped on the per-stage response).

## 5. Credit balance & shortfall (both modals)

Shortfall = `max(0, needed − available)`; banner shows only when `shortfall > 0 AND needed > 0`.

- **Needed > available → shortfall banner** "You are short N credit(s). The first {available} candidate(s) will get summaries generated; the rest will be skipped." Verify numbers + plurals; submit is STILL allowed (partial run proceeds).
- **Zero available credits → submit BLOCKED by validation** with "no credits available — purchase credits to generate summaries" (form error, no POST). Distinct from the shortfall case, which DOES POST.
- **Balance query errors → treated as 0 available** → full shortfall banner and validation blocks submit (modal degrades to the zero-credit path, not a stale real balance).

## 6. Submit response toast (immediate queue result)

On confirm a single toast is composed from `queuedCount` / `skippedCount` / `anyTextractPending`, fragments joined by ". "; each appears only when non-zero:

- queued > 0 → "Queued N summary generation(s)".
- skipped > 0 → "N skipped (no resume or already processing)".
- textract pending → "some resumes are still processing".
- **All zero → "No summaries to generate"** — still a **success** toast (not a warning).
- **Failure → warning toast** "Failed to queue summaries" (or the server's general error), with a longer ~10s dismiss.
- **Per-stage only:** on success the selection is cleared (`resetList`) and checkboxes reset. The whole-job modal does not touch a list.
- **Double-submit guard:** the confirm button shows loading + disabled during the request — a fast double-click must not fire two POSTs.

## 7. Async completion — arrives after the Sidekiq batch runs

The confirm toast only reports queueing; the real outcome comes later (websocket + email).

- **Live completion toast** to the acting user once the batch finishes, with succeeded / failed / skipped counts — no page reload.
- **Whole-batch-failure variant:** if 0 succeeded and ≥1 failed, the toast/email is the failure copy "We couldn't complete your Plato reviews for {job title}" instead of the success completion.
- **Result email** to the acting user; whole-job link → job stages, per-stage link → that stage's applicants.
- **Candidate rows update after completion without reload:** reviewed rows gain fit swatches; in-progress rows show the hourglass. Confirm the list, job header, and credit balance refetch (the mutation invalidates stage list / job / balance caches).

## 8. Role-fit filter interaction (regression-sensitive; Select-All resolves server-side)

Select-All resolves candidates on the server against the applied "Filter by fit" filter — no client-side ID array is sent.

- **Filter applied + Select-All + Generate → only the filtered band is processed** (minus deselected, minus already-scored). Verify the count and the actual candidates acted on match the visible filtered set, NOT the whole stage.
- **No filter applied → whole-stage behavior unchanged** (empty `roleFit` must not drop or add anyone vs production).
- After a stage switch (filters reset), a Select-All acts on the full unfiltered stage.

## 9. Feature-flag & menu visibility

- **`Generate AI summaries` appears in `Bulk options` only with the flag ON.** Flag OFF → dropdown shows just Message / Move candidates, no AI item.
- **`Run Plato` CTA card renders only with the flag ON** on the job stages view.
- **Bulk options / stage menu appears only when the stage has candidates** (count > 0) — an empty stage shows no bulk menu.

## 10. Shared regression — bulk Message / Move counts (the AI work changed JobStageMenu math)

JobStageMenu now derives selection counts from the filtered list total (`selectableCount ?? stage.jobApplicationsCount`), affecting the two PRE-EXISTING bulk actions.

- **Bulk Message and Bulk Move counts** on Select-All and Select-All-minus-exclusions must still be correct with NO filter applied (equal the stage count) and the same recipient/move set as production.
- **With a fit filter applied**, Select-All for Message/Move now targets the filtered set — confirm counts and the acted-on set match the filtered band (and that this is intended).
- No count regression on a stage where count > 0 but rows aren't yet loaded (falls back to stage count).
