# SPEC (WIP) — Plato bulk re-score (stage trigger) + touchups

**Branch/worktree:** `inflow-ats.job-criteria-settings` (`job-criteria-settings-qa`)
**Status:** WIP — scope being defined. Item 1 below is confirmed; more items pending from Jessica.

---

## Item 1 — Per-stage bulk trigger: allow re-score

### Problem
The **per-stage** bulk "Run Plato reviews" trigger can't request a re-score of already-scored candidates. Its modal hardcodes the flag off, unlike the **all-stages** trigger, which already has the toggle.

### Current state (traced 2026-07-10)
**Backend — already wired, and shared by both triggers:**
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb:79` — `bulk_params.require(:rescore_requested)` (required).
- `app/interactors/queue_bulk_ai_summary_jobs.rb:41` — `unless context.params[:rescore_requested]` re-includes already-scored (`AiJobApplicationSummaryStatus` `:current`) candidates when the flag is true; passes `rescore_requested` into the job payload (:107).
- `app/jobs/bulk_generate_ai_summaries_job.rb:47` — sets `job_application.ai_summary_rescore_requested = payload['rescore_requested']`.
- `app/interactors/create_bulk_ai_summary_generation.rb:45` — when the flag is set, builds a **new** `AiJobApplicationSummary` (instead of returning the existing active one), so `TextractResult#generate_ai_summary_with_credit_flow` proceeds and re-scores.

**Frontend:**
- ✅ **All-stages** `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx` — has the re-score checkbox: `rescore` state (:35), `Styled.RescoreCheckbox` (:135), sends `rescoreRequested: rescore` (:60), and adjusts `candidatesToScoreCount` (:40).
- ❌ **Per-stage** `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx:74` — hardcodes `rescoreRequested: false`. No checkbox. **This is the gap.**
- Hook `app/javascript/shared/queryHooks/useBulkGenerateAiSummaries.ts` already carries `rescoreRequested` in its types (:10, :41).

### Proposed change
Add the re-score checkbox to `BulkGenerateAiSummariesConfirmModal`, mirroring `RunPlatoReviewAllModal`:
- `rescore` state + checkbox (`Styled.RescoreCheckbox` analog).
- Send `rescoreRequested: rescore` instead of the hardcoded `false`.
- Mirror the `candidatesToScoreCount` adjustment so the count reflects re-scoring already-scored candidates.
- No backend change needed — same controller/interactor path as all-stages.

### Open questions
- Copy for the stage-trigger checkbox (match all-stages wording, or stage-specific?).
- Should the checkbox be hidden/disabled when the stage has no already-scored candidates?

### Tests
- Frontend: extend/add coverage for `BulkGenerateAiSummariesConfirmModal` sending `rescoreRequested` true/false.
- Backend already covered (`queue_bulk_ai_summary_jobs_spec` "when rescore_requested is true").

---

## Item 2 — Single-send Regenerate: allow explicit re-score of an already-scored candidate

### Goal
Let "Regenerate" re-score a single candidate that already has a summary — regardless of the candidate's/job's/resume's state (subject to the real guards below). The **explicit Regenerate click** must be distinct from accidentally clicking Generate twice, so a re-score is only ever an intentional action (and only then re-charges a credit).

### Current state (traced 2026-07-10)
- **The single path cannot re-score.** `app/interactors/create_ai_summary_generation.rb:36-39` — `if active_ai_summary { context.ai_summary = active_ai_summary; return }` returns the existing active (non-failed, non-stale) summary unconditionally. There is **no** rescore flag here (contrast `create_bulk_ai_summary_generation.rb:45`, which builds a NEW summary when `ai_summary_rescore_requested`).
- Even past that, `TextractResult#generate_ai_summary_with_credit_flow:68` — `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` — blocks re-gen; but creating a NEW summary sidesteps it (latest becomes the new pending row).
- Single-send trigger: `app/controllers/api/v1/ai_job_application_summaries_controller.rb` → `ValidateAiSummaryGeneration` → `CreateAiSummaryGeneration` → enqueues `GenerateAiJobApplicationSummaryJob` → `generate_ai_summary_with_credit_flow`. (Auto path: `job_application.rb:200`.)
- Frontend: the **Regenerate** button lives in `app/javascript/ats/src/views/jobApplications/Plato/PlatoSummary.tsx`; today it hits the generate path and no-ops on an already-scored candidate.

### Approach — thread the rescore flag through the interactor (no new endpoint)
Separate endpoint dropped (Jessica: no point — the guards live in the interactor/pipeline, not the endpoint). The lever already exists: `app/models/job_application.rb:11` — `attribute :ai_summary_rescore_requested, :boolean, default: false` (bulk sets it; the single path never does).

**The two — and only two — return-guards that bail on a pre-existing non-stale succeeded summary:**
1. **`app/interactors/create_ai_summary_generation.rb:36-39`** — the operative block. Returns the existing active (`where.not(status: :failed).where(stale: false)` latest) summary → no new summary, no job enqueued. Bulk analog `create_bulk_ai_summary_generation.rb:45` already gates this on `&& !job_application.ai_summary_rescore_requested`.
2. **`app/models/textract_result.rb:68`** (`generate_ai_summary_with_credit_flow`) — `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. **Backstop only** — self-resolves once guard 1 builds a new summary (latest becomes the new pending row).

**Minimal change:** set `ai_summary_rescore_requested` on the manual-regenerate trigger and add `&& !job_application.ai_summary_rescore_requested` to guard 1 (mirror bulk). Guard 2 then passes on its own — no change needed there, but verify.

### Guards to preserve
- Regenerate still respects the real `ValidateAiSummaryGeneration` guards (resume present, job description present, credits available, textract ready). It bypasses ONLY the "already has a succeeded, non-stale summary" idempotency block (guard 1).

### Decisions (Jessica, 2026-07-10)
- **Do NOT mark the prior succeeded summary `stale`.** Leaving it non-stale keeps `latest_succeeded_ai_job_application_summary` populated, which is what drives the `regenerating` display (prior score/headline shown while the re-score runs).
- **Confirm modal before regenerate: yes — already built into the Regenerate button. Not changing it.**

### Status record — VERIFIED, no change needed
`FindOrCreateAiJobApplicationSummaryStatus#resolve_status` already handles any regeneration:
```ruby
def regeneration_in_progress?
  generation_in_progress? && latest_succeeded_ai_job_application_summary.present?
end
```
It does **not** check `stale`, so re-scoring a non-stale succeeded summary takes the same `current → regenerating → current` path as regenerating a stale one. It's called mid-flow from `generate_ai_summary_with_credit_flow:72`, so once guard 1 lets a new pending summary be built, status → `regenerating` (keeps prior score on screen), then → `current` with the new score on success. **No status-record work required.**

### Remaining work (net)
1. Add `&& !job_application.ai_summary_rescore_requested` to guard 1 (`create_ai_summary_generation.rb:36`), mirroring bulk.
2. Set `ai_summary_rescore_requested = true` on the manual Regenerate trigger (frontend passes it; controller permits it; thread it to `job_application` before `CreateAiSummaryGeneration`).
3. Keep all `ValidateAiSummaryGeneration` guards (resume/description/credits/textract).

### Open questions
- Mark the prior summary `stale: true` on regenerate, or leave it and let the new one supersede via the status record?
- Confirm-modal before regenerate (it re-charges a credit)?
- Endpoint shape for (b): new route/action on `ai_job_application_summaries_controller`, or a sibling controller?
- Does the frontend Regenerate button need `disabled` while in flight (rule 11 — loading must pair with disabled)?

### Tests
- Backend: regenerate on an already-scored candidate builds a new summary, charges one credit, respects the standard guards; double-Generate does NOT re-charge.
- Frontend: Regenerate targets the new path; guard/disabled behavior.
