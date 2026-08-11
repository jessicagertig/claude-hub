# Job Criteria in Plato AI Settings — Decisions of Record

Decisions made by Jessica in conversation on 2026-07-02/03. These are binding on the spec, plan, and implementation. Where a design file conflicts with this document, THIS DOCUMENT WINS.

## Feature summary

Expose the AI-extracted job criteria to the user in the per-job **Plato AI settings** tab (Job Setup → Plato AI settings, `JobSetupAiSettings.tsx`). Three capabilities:

1. **Get** the job criteria (fetch from backend — currently not serialized anywhere).
2. **View** the job criteria (FullModal right slide-over, read-only).
3. **Regenerate** the criteria from the frontend (POST endpoint → async extraction → WebSocket success toast from backend).

## Design sources (in priority order)

1. `design/bundle-1-decisions/Job criteria - decisions.html` — the DECIDED design (artboards marked "decided"). Ground truth for structure, layout, copy.
2. `design/bundle-3-reference-tsx/` — reference TSX written against real codebase imports (`JobSetupAiSettings.tsx`, `JobCriteriaModals.tsx`). Strong starting skeleton; verify every import/prop against the real codebase.
3. `design/bundle-1-decisions/README.md` — index only; carries some OLD-design content (see exclusions).

**Take structure and styles ONLY from design files. Discard their variable names.** Naming comes from the codebase and `cursor_rules/`. (Jessica: "Please do not take the variable names as used by Claude AI design.")

## Decided IN

- **Job criteria FormSection** below the existing "Plato reviews" FormSection: intro text, criteria card (Plato disc + title + relative-time description, count rail with Core/Preferred/Bonus rows; Bonus row only when bonus criteria exist), action row (`View criteria` secondary + `Generate criteria`/`Regenerate criteria` secondary).
- **Sidebar tier glossary** via `SettingsContainer`'s existing `sidebar` prop (Team-roles aside register). Copy per decisions.html wording:
  - Core lead: "Must-haves that count most toward a candidate's score."
  - Preferred lead: "Nice-to-haves that count toward the score, less than core criteria."
  - Bonus lead: "A small boost when a candidate has them."
  - (Jessica: copy will be iterated later — use these for the draft.)
- **View criteria slide-over**: FullModal right panel, header "Job criteria" + X icon button, description paragraph, single bordered list container grouped by tier (tier head row = icon + label + count; criterion rows). Empty tiers omitted. Read-only, no hover states, no footer. **NO tier hint sentences under tier heads** (decided OUT).
- **Regenerate confirmation modal — MANUAL variant only**: title "Regenerate job criteria?", manual lead paragraph, bordered statement box with `refresh-cw` icon and the regeneration advice copy, footer primary `Regenerate criteria` + secondary `Cancel`.
- **Empty states** (replace the card; existing `EmptyState` component, standard — NOT roomy, NOT borderless):
  - Never extracted: `icon="file-text"`, title "No job criteria have been generated", message "Plato extracts scoring criteria when you publish the job, or you can generate them now." Button label `Generate criteria`; no View button.
  - Extraction ran, found nothing: `icon="alert-triangle"`, title "No criteria found", message "No scoring criteria were found in the job description. Plato won't review candidates until it has criteria to score against." Button `Regenerate criteria` only; no View button.
- **Section intro must ALSO explain the automatic lifecycle** (Jessica addition, not in design files): criteria are extracted automatically when the job is published, and re-extract automatically when the description is updated while published. User must learn this from the UI. Draft the sentence(s); copy iteration expected.
- **Loading states** (Jessica: recent failure mode is MISSING loading states — do not repeat it):
  - Initial criteria fetch: the normal Polymer loading bar treatment used elsewhere in the app (find the codebase pattern).
  - Extraction in flight (regenerate clicked, or extraction already running when tab loads): frontend must know from BACKEND STATUS that extraction is running — not just local mutation state. Regenerate/Generate button shows loading. Survives page reload (status comes from the fetched payload).
- **Failure state** (extraction failed for a reason other than zero-criteria): not designed — use the same EmptyState pattern with a different message. Draft the copy.
- **Regenerate allowed in ANY job state** — draft, unpublished, published. (Jessica: "as a user, I want to be able to regenerate job criteria whenever I fucking want to.")
- **Regenerate authorization = `JobPolicy#update?`** (hiring-team member OR org admin), NOT `update_ai_settings?`/`can_use_ai_credits?`. (Jessica, 2026-07-03, mid-QA): regeneration consumes no credits, and editing the job description already re-triggers extraction for any hiring-team member — so the button must use the same gate as editing the job. Nothing should block a hiring-team member or admin from regenerating. Read access (GET show) stays `show?` (same effective set). This overrides the spec's original agent-chosen `update_ai_settings?` gate, which spec review had graded "spec-compliant" without surfacing it as a decision.

## Decided OUT (do not build)

- **Guard modals** (≤5-criteria warning, 0-criteria hard-stop popups). Old-design carryover present in README + bundle-3 TSX (`guard` state, GuardTitle/GuardBody/GuardFoot). Jessica: wants eventually, NOT designed yet, NOT in this feature. The zero-criteria case is handled entirely by the empty state.
- **After-description-update regenerate confirm variant** ("You just updated the job description…" / secondary "Keep current criteria"). Designed artboard exists but trigger is not worked out. Manual variant only ships. Do not build the trigger.
- **Tier hint sentences** under tier heads in the View slide-over.
- **`internal_job_criteria`** (`jobs` text column, currently dead): future phase — user-entered criteria source not shown in the job description. DO NOT touch, reference, or build on it.

## Backend decisions

- Criteria live on `AiJobCriteria` (`ai_job_criteria` table): `job_id`, `status` enum (pending/in_progress/succeeded/failed/retrying), `criteria` jsonb (array of `{text, tier, source_heading}`, tier ∈ tier_1/tier_2/tier_3), `metadata` jsonb, `error_message`. History table — newest succeeded row is current (`Job#latest_succeeded_ai_job_criteria`).
- **Serialize only what the UI needs** — the criteria themselves plus enough status for the UI states (loading/generating, failed, never-extracted, zero-found) and the extracted-at time for the card's relative timestamp. NOT the whole record. Whether it rides an existing job serializer or a dedicated endpoint: follow the closest AI-scoring analog in the codebase.
- Payload shape mapping (design assumed `tier1/tier2/tier3 + extractedAt`) is OURS to define per codebase conventions — design's assumption is not binding.
- **Regenerate = POST endpoint** following existing AI-scoring controller patterns. Calls `Job#extract_job_criteria_immediately`.
- **`extract_job_criteria_immediately` gating** (Jessica-approved change, ALREADY MADE in the main checkout but UNCOMMITTED there — the worktree does NOT have it; implement it as part of this feature):
  ```ruby
  def extract_job_criteria_immediately
    return unless description.present?
    return if latest_ai_job_criteria&.status_in_progress?
    return if latest_ai_job_criteria&.status_retrying?

    new_ai_job_criteria = ai_job_criteria.new(status: :pending)
    return unless new_ai_job_criteria.save

    ExtractJobCriteriaJob.perform_later(new_ai_job_criteria.id)
  end

  def extract_job_criteria_if_needed
    return if latest_ai_job_criteria&.status_succeeded?

    extract_job_criteria_immediately
  end
  ```
  (Guards moved INTO `_immediately`; duplicated guards dropped from `_if_needed`, which keeps only the `succeeded` guard.)
- **Blank job description**: regenerate endpoint must return an error message when the description is blank (zero characters — `description.present?` false). Frontend surfaces it (toast per existing error pattern). Do not let the button spin forever on a no-op.
- **Async completion notification**: WebSocket success toast triggered from the backend when extraction completes. Prior patterns exist in the codebase for backend-triggered WebSocket toasts on AI events — find and mirror the analog. Frontend also refreshes the criteria payload on completion.
- **No reviews may run while the job has zero criteria** (extraction ran and found none): Jessica confirmed this is NOT currently enforced by the backend and must be. When there is a completed extraction with zero usable criteria, new AI summary reviews must be stopped from firing (they would burn the first pipeline steps pointlessly). Spec must trace the summary-creation entry points and define WHERE this guard lives. Note: per `ExtractCriteria`, a zero-criteria outcome currently lands as status `failed` with error_message "No criteria extracted from job description" / "No criteria sections found in job description" — succeeded rows always have ≥1 criterion. The spec must define how "extraction ran and found nothing" is distinguished from "never ran" and from other failures, for BOTH the backend guard and the two distinct frontend empty states.

## Copy rules (binding, from design)

- No em dashes. Sentence case. No emoji.
- "extract", never "read". "count most/less toward the score", never "weight/heaviest".
- Button labels are static — never interpolate counts into them. Counts may appear in titles/body text.
- Timestamps live in the card description, never beside buttons.
- Scoring is point-in-time: each review keeps the criteria it was scored against; regeneration never rewrites existing reviews. Never write "candidates will be rescored".

## Visual specs

- Follow decisions.html + bundle-3 styled-components for values (they agree): card max-width 560px, radius 7px, Plato disc 36px with `linear-gradient(120deg, #FBD7FF 10%, #FFDEC1 90%)` + inset ring, count rail 186px, description copy 14px/400/1.6 secondary, card meta 12.5px/1.3, weights 400/450/500/600 only, tabular figures on counts/timestamps, Feather icons 2px stroke (`check-circle`, `plus-circle`, `star`, `x`, `refresh-cw`, `alert-triangle`, `file-text`), monochrome neutrals + accent gradient only. Swap raw values for poly theme tokens where they exist.
- PlatoMark asset already exists in production — reuse it.
- Emotion rule: separate styled components for visual variants, never conditional props (pipeline rule 12).

## Process requirements

- Full LIFECYCLE run (Phases 0-8), Jessica offline — orchestrator acts as the human gate, including reviewing/regenerating REVIEW-ANGLES.md itself.
- REVIEW-ANGLES.md must include a cursor_rules-compliance angle; plus a dedicated conventions-only review pass after Phase 6 convergence (one reviewer per relevant `cursor_rules/` file, "ONLY these rules" framing, VIOLATIONS + MISSING, file:line evidence).
- Spec must include a test plan (pipeline rule 3): RSpec + frontend coverage expectations, and which existing tests change.
- Branch: `job-criteria-settings` off `qa-refinements`, worktree `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings`.
