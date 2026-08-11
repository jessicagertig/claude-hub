# SPEC — Plato re-score: per-stage bulk checkbox + single-send Regenerate

**Date:** 2026-07-11
**Worktree/branch:** `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings` (`job-criteria-settings-qa`)
**Source of truth:** every requirement below was confirmed in `approved-decisions.md` (same directory). No requirement here is new.

---

## Background — current state (no changes described in this section)

- The bulk backend path is complete and shared by both bulk triggers: `Api::V1::BulkAiJobApplicationSummariesController` requires `rescore_requested` in both `create` and `all_stages` (`bulk_ai_job_application_summaries_controller.rb:79`); `QueueBulkAiSummaryJobs` re-includes already-scored candidates when the flag is true (`queue_bulk_ai_summary_jobs.rb:41`) and passes it into the job payload (`:107`); `BulkGenerateAiSummariesJob#each_iteration` sets `job_application.ai_summary_rescore_requested` from the payload (`bulk_generate_ai_summaries_job.rb:47`); `CreateBulkAiSummaryGeneration` builds a new summary when the flag is set (`create_bulk_ai_summary_generation.rb:45`).
- The all-stages modal `RunPlatoReviewAllModal.tsx` already has the re-score checkbox. The per-stage modal `BulkGenerateAiSummariesConfirmModal.tsx` hardcodes `rescoreRequested: false` (`:74`) and has no checkbox.
- The single-send path cannot re-score: `CreateAiSummaryGeneration` returns the existing active summary unconditionally (`create_ai_summary_generation.rb:36-39`). The Regenerate button in `PlatoTab.tsx` renders only for stale current reviews (`:247`) and no-ops on non-stale ones.
- `stale` on `AiJobApplicationSummary` has exactly one meaning — the resume was replaced. Nothing in this spec writes `stale`, reads it in new logic, or changes any stale semantics.

---

## Item 1 — per-stage bulk re-score checkbox + modal copy restructure

### 1.1 `BulkGenerateAiSummariesConfirmModal.tsx` — add the checkbox

- Import `FormCheckbox` from `@ats/src/components/forms/FormCheckbox`.
- Add state: `const [rescore, setRescore] = React.useState(false);`
- Add the checkbox block between the body copy and `FormContainer`, structure copied from `RunPlatoReviewAllModal.tsx:135-143`: a `Styled.RescoreCheckbox` div wrapping `FormCheckbox` with `name="rescore"`, label "Also re-review candidates that already have a review", description "Recommended if you've changed the candidate requirements in the job description.", `checked={rescore}`, and an `onChange` that toggles the state. `Styled.RescoreCheckbox` is a `styled.div` containing only `${t.mt(4)}`, emotion label `BulkGenerateAiSummariesConfirmModal_RescoreCheckbox`.
- In the `bulkGenerate` call, replace the literal `rescoreRequested: false` with `rescoreRequested: rescore`.
- The checkbox renders disabled (visible, not checkable) in the no-selection state (`candidatesCount === 0`) — same disabled condition as the submit button in that state.

### 1.2 `BulkGenerateAiSummariesConfirmModal.tsx` — copy restructure

Delete the current four-branch `instructions` block, the `shortfallText` fragment, the `Styled.Caveat` block, and the `Styled.Callout` block. Replace with the analog-style structure below. The working count is `candidatesToScoreCount = rescore ? candidatesCount : processableCount` and `shortfall = Math.max(0, candidatesToScoreCount - available)`.

States, in precedence order:

1. **No selection** (`candidatesCount === 0`): keep today's copy verbatim — "No candidates selected. Use the checkboxes next to the candidate names to select the candidates to generate reviews for. To select all candidates within this hiring stage, use the checkbox next to the stage name." Submit button disabled; checkbox disabled.
2. **Unchecked, zero processable** (`!rescore && processableCount === 0`): body reads "0 of the {candidatesCount} candidates selected from this hiring stage don't have a Plato review yet. Unless you select re-review below, no candidates will be reviewed." Numeric 0, not the word. No credit sentence. Submit button disabled.
3. **Unchecked, processable** (`!rescore && processableCount > 0`): lead sentence "{processableCount} of the {candidatesCount} candidates selected from this hiring stage don't have a Plato review yet." — prefixed with "Up to " when `isProcessableCountExact` is false. Then the credit copy verbatim from the analog with per-stage counts: "Each successful review uses one AI credit" followed by either the shortfall variant ". You are short **{shortfall}** credit(s). The first {available} candidate(s) will get reviews generated; the rest will be skipped." (when `shortfall > 0`) or the normal variant ", so running this uses up to **{candidatesToScoreCount}** credit(s) from your balance of **{available}** available." Submit button enabled.
4. **Checked** (`rescore`): lead sentence "The {candidatesCount} candidates selected from this hiring stage will be reviewed, including candidates that already have a review." followed by the same credit copy as state 3 with `candidatesToScoreCount = candidatesCount`. No "Up to" prefix and no overestimate info block — the count is exact even mid-load. Submit button enabled.

Singular/plural interpolation follows the analog's existing `{count === 1 ? ... : ...}` pattern throughout.

Submit button disabled condition: `isLoading`, or state 1, or state 2. (States 3 and 4 enable it.)

### 1.3 `BulkGenerateAiSummariesConfirmModal.tsx` — overestimate info block

Renders only when `isProcessableCountExact === false && !rescore`, directly beneath the body copy. Structure copied from `CustomQuestionModal` (`app/javascript/ats/src/components/modals/CustomQuestionModal/index.js:192-199`): a `Tooltip` (from `@ats/src/components/shared/Tooltip`) wrapping a `Styled.Info` div containing `Icon name="alert-circle"` and a span.

- Visible short message: "This count may be an overestimate."
- `Tooltip` `label`: "This is not an exact count of candidates without a review. If fewer candidates than stated above are unreviewed, only those unreviewed candidates will be reviewed, and fewer credits will be consumed."
- `Styled.Info` styles copied verbatim from `CustomQuestionModal`'s `Styled.Info` (`t.text.xs`, `t.mt(-1)`, `t.mb(5)`, gray[400] dark / gray[600] light, flex, `align-items: center`, `line-height: 1.3`, svg sizing block, hover cursor text), emotion label `BulkGenerateAiSummariesConfirmModal_Info`.

### 1.4 `BulkGenerateAiSummariesConfirmModal.tsx` — Statement block

Replaces the deleted Callout. Structure copied verbatim from `RunPlatoReviewAllModal.tsx`'s `Styled.Statement` (`:145-151` usage, `:186-206` styles — bordered flex box, `Icon name="mail"`, `t.text.sm`), emotion label `BulkGenerateAiSummariesConfirmModal_Statement`. Copy:

"You will receive an email with the final count when it's done. Candidates without a resume, one that's still processing, or those already part of another bulk operation are skipped."

### 1.5 `RunPlatoReviewAllModal.tsx` — defect fixes (all-stages modal)

- **Checked-state body sentence** (fixes the defect where the count includes already-reviewed candidates while the sentence claims otherwise): when `rescore` is checked, the body's first sentence becomes "{candidatesCount} candidate(s) in this job will be reviewed, including candidates that already have a review." — NO leading "The", deliberately differing from the per-stage sentence (which has it because a selection was made). The credit sentence that follows is unchanged. Unchecked copy unchanged.
- **Zero-state** (unchecked, `candidatesToScoreCount === 0`): body becomes "0 candidates in this job don't have a Plato review yet. Unless you select re-review below, no candidates will be reviewed." Numeric 0. No credit sentence. Button stays disabled via the existing `candidatesToScoreCount === 0` condition.
- **Statement second sentence** becomes "Candidates without a resume, one that's still processing, or those already part of another bulk operation are skipped." First sentence ("The hiring team gets an email with the final count when it's done.") stays — made true by 1.6.

### 1.6 `BulkAllStagesAiSummaryResultMailer` — hiring-team recipients

In both `complete` and `failed`: replace the single-user `to:` with every active hiring-team member of the job, resolved like `JobApplicationMailer#hiring_team_new_job_application` (`job_application_mailer.rb:19,28-32`) but WITHOUT the preference scope: `job.organization_users.actives`, mapped to `{ name, email }` entries, all in one email's `to:` array. No opt-out filter — no Plato-bulk preference key exists. Guard `return unless recipients.any?` as in the analog mailer method.

Greeting removed entirely (owner-ruled 2026-07-11, resolving the prior escalation): in both `complete` and `failed`, drop `user_first_name` from the `variables` hash and remove the `@user = User.find(user_id)` load — the `user_id` argument stays in both method signatures so callers are unchanged, it is simply no longer read.

Template edits in the polymer-mail repo (`/Users/jessica/wrk/wrk-corp/polymer-mail`): delete the `<p>Hi {{user_first_name}},</p>` line (line 30 in both) from `transactional/user-facing/user-bulk-all-stages-ai-summary-complete.mjml` and `transactional/user-facing/user-bulk-all-stages-ai-summary-failed.mjml`. No replacement greeting — this matches the analog multi-recipient templates (`new-application-received.mjml`, `new-job-application-comment.mjml`, `new-message-received.mjml`), none of which has a greeting line. MANUAL DEPLOY STEP for Jessica after merge: paste both updated templates into Mailgun.

`BulkJobApplicationAiSummaryResultMailer` (per-stage) and its templates (`user-bulk-ai-summary-complete.mjml`, `user-bulk-ai-summary-failed.mjml`): no change — triggering user only, personal greeting stays correct.

### 1.7 Item 1 tests

- Extend `spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb`: active hiring-team members included, inactive members excluded, for both `complete` and `failed`. This spec is currently STALE against the mailer and must be reconciled as part of the extension (it cannot pass as-is): (a) the `#complete` example calls `complete(user.id, job.id, 5, 1, 2)` — 5 args against the 6-arg signature `complete(user_id, job_id, succeeded_count, failed_count, skipped_count, total)` → `ArgumentError`; add the missing `total` arg; (b) `#complete` asserts subject `"Your AI summaries for … are ready"` and tags `['polymer','user-facing','ai-summaries']`, but the mailer emits subject `"Your Plato reviews for #{@job.title} are ready"` and tags `['polymer','user-facing']` — update both; (c) `#failed` asserts subject `"We couldn't generate AI summaries for …"`, but the mailer emits `"We couldn't complete your Plato reviews for #{@job.title}"` — update it; (d) both examples assert `params[:to].first[:email]).to eq(user.email)` on a single recipient — replace with the multi-recipient assertions (active team members present, inactive absent) so the recipient change is actually exercised. Reconcile these against the real mailer, do not layer recipient assertions on top of already-failing expectations. (e) Assert `variables` does NOT contain `user_first_name` in either method — the greeting variable is removed per 1.6.
- No frontend tests (ruled: frontend coverage not wanted).
- Existing `queue_bulk_ai_summary_jobs_spec.rb` and `bulk_ai_job_application_summaries_controller_spec.rb` already cover `rescore_requested` threading — no changes.

### 1.8 Item 1 — explicitly untouched

- The per-stage no-selection branch copy (kept verbatim, state 1 above)
- `BulkJobApplicationAiSummaryResultMailer` recipients
- The `"job"` query-invalidation difference between `useBulkGenerateAllStagesAiSummaries` and `useBulkGenerateAiSummaries` (intentional)
- posthog `trackEvent` names and payloads in both modals
- The entire backend enqueue path

---

## Item 2 — single-send Regenerate re-score

**Scope (one behavior):** enable regenerating an `AiJobApplicationSummary` when `ai_summary_rescore_requested` is passed as true, for a candidate that already has a succeeded, non-stale summary. No new resume, no new textract result involved. The bulk interactor is the source for the gate condition only — no other behavior of either interactor is compared or ported.

### 2.1 `CreateAiSummaryGeneration` — the gate (only gate changed)

`create_ai_summary_generation.rb:36`: the condition `if active_ai_summary` becomes `if active_ai_summary && !job_application.ai_summary_rescore_requested` — identical to the condition at `create_bulk_ai_summary_generation.rb:45` in the bulk interactor. With the attribute true, the interactor falls through to building a new pending `AiJobApplicationSummary` and enqueuing `GenerateAiJobApplicationSummaryJob`, exactly like a first generation. Nothing else in the interactor changes.

Zero edits to the other eight gates on this path: controller existence/tenancy check, Pundit `create?` policy, `ValidateAiSummaryGeneration` (flipper / resume / credits / description / textract), job entry `return unless textract_result`, the `textract_result.rb:68` succeeded-and-not-stale return (self-resolves — the new pending row becomes `latest_ai_job_application_summary`), job-criteria readiness, `Orchestrate` entry checks, charge-on-success + `CreateAiCreditBalanceTransaction` balance check.

### 2.2 `Api::V1::AiJobApplicationSummariesController#create` — param boundary

Add the controller's single params method (per core rule 5), named `ai_job_application_summary_params`: `params.require(:ai_job_application_summary)` then `.require(:rescore_requested)` on the result (Rails `require` special-cases `false` as present — the same reason the bulk controller's identical `require` works). In `create`, set `job_application.ai_summary_rescore_requested = <the required value>` before `CreateAiSummaryGeneration.call` — the same placement the bulk path uses (attribute set on the record just before the interactor). Rationale on record: interactors do not enforce parameters; requiredness lives in strong params at the controller boundary.

### 2.3 `useAiJobApplicationSummary.ts` — hook param

`GenerateParams` gains `rescoreRequested: boolean` — required, no optional marker. It rides into the existing POST body (`{ aiJobApplicationSummary: params }`) with no other hook changes.

### 2.4 `PlatoTab.tsx` — callsite wiring (exact shape pinned)

- `handleGenerate` gains a required boolean parameter `rescoreRequested` — no default value — and passes it into the mutation: `generate({ jobApplicationId: jobApplication.id, rescoreRequested }, ...)`.
- All four callsites pass the literal explicitly:
  - The three `PlatoTabEmptyState` onClick paths (bulkQueued, failed, ready/noCredits) become `onClick={() => handleGenerate(false)}` — arrow-wrapped so the click event cannot ride in as a truthy argument.
  - The Regenerate `ConfirmationModal` `onConfirm` calls `handleGenerate(true)` after its existing `removeModal()`.

### 2.5 `PlatoTab.tsx` — Regenerate button gating

The header-right condition at `:247` changes from `statusValue === "current" && fullSummary?.stale` to `statusValue === "current"` alone — Regenerate renders for every current review, stale or not. Everything inside the branch stays exactly as-is: the credits check (`isLoadingCredits || totalRemaining > 0`) choosing between the Regenerate button and the Buy-credits fallbacks (admin nav button / non-admin alert modal), the `ConfirmationModal` copy, and the button's `loading={buttonLoading} disabled={buttonLoading}` pairing.

### 2.6 Delete `AiSummaryState.tsx`

Delete `app/javascript/ats/src/views/jobApplications/AiSummaryState.tsx` — dead code with zero references in `app/` or `cypress/`, superseded by `PlatoTab.tsx` and, left in place, a compile failure once `rescoreRequested` is required in `GenerateParams`.

### 2.7 Intended behavior on record (no code changes)

- After a successful re-score the candidate has two `AiJobApplicationSummary` rows with `status: succeeded, stale: false`; readers resolve the operative row by newest `created_at` or via the status record's `ai_job_application_summary_id`. Works as intended.
- The status record takes the existing `current → regenerating → current` path via `FindOrCreateAiJobApplicationSummaryStatus` (`regeneration_in_progress?` does not check `stale`); the prior score stays on screen during the re-score. No status-record changes.
- A successful re-score consumes one AI credit exactly as any successful generation does; the Regenerate confirm modal already states this.

### 2.8 Item 2 tests

- Create `spec/interactors/create_ai_summary_generation_spec.rb` (file does not exist): with an active non-stale succeeded summary, `ai_summary_rescore_requested` true builds a new pending summary and enqueues `GenerateAiJobApplicationSummaryJob`; false returns the existing summary and enqueues nothing — the same assertion pairs `create_bulk_ai_summary_generation_spec.rb` makes for the bulk interactor. NOTE: the `validation_result` double must ALSO stub `textract_pending: false` (e.g. `double('validation_result', textract_result: textract_result, textract_pending: false)`). Unlike the bulk interactor, `CreateAiSummaryGeneration` reads `validation_result.textract_pending` (`create_ai_summary_generation.rb:41`) on the fall-through (rescore-true) path; a double copied verbatim from the bulk spec (which omits it) would raise on the unstubbed message.
- Create the controller spec for `Api::V1::AiJobApplicationSummariesController` (file does not exist): request without `rescore_requested` is rejected; with it, the value threads onto the record.
- No frontend tests.
