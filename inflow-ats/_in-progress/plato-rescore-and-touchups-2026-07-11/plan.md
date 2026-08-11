# Implementation Plan — Plato re-score: per-stage bulk checkbox + single-send Regenerate

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Repo/worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings` (branch `job-criteria-settings-qa`, HEAD `f8815555a`)
**Authoritative requirements:** `SPEC.md` (two clean review passes — `reviews/SPEC-REVIEW-COMPLETE.md`). Owner rulings in `approved-decisions.md`. Reviewer guardrails in `reviews/REVIEW-ANGLES.md`.

**READ THIS FIRST — pins are law.** Every string, style, condition, and callsite shape below is pinned verbatim from the SPEC, which in turn copied them verbatim from the named source files. Do **not** paraphrase copy, do **not** "improve" wording, do **not** re-derive from the analog on your own — type the pinned text exactly. Where the per-stage modal deliberately diverges from the all-stages modal (e.g. leading "The"), that divergence is owner-ruled; keep it.

---

## Summary

Two small gaps in Polymer's "Plato" AI candidate review are closed.

**Item 1 (per-stage bulk):** the per-stage "Review candidates" modal (`BulkGenerateAiSummariesConfirmModal.tsx`) gains the same "also re-review already-reviewed candidates" checkbox the whole-job modal already has, and its body copy + credit math are restructured to match the whole-job modal's 5-state precedence copy. The whole-job modal (`RunPlatoReviewAllModal.tsx`) gets three copy defect fixes. The whole-job result email (`BulkAllStagesAiSummaryResultMailer`) is widened from the triggering user to the whole active hiring team (both `complete` and `failed`).

**Item 2 (single-send):** the single-candidate "Regenerate" button can now re-score a candidate that already has a succeeded, non-stale review. One interactor gate gains one condition, the controller gains a required strong-param, the hook type gains a required field, `PlatoTab.tsx` threads the boolean through four callsites, and the dead `AiSummaryState.tsx` is deleted.

The shared bulk backend enqueue path is unchanged (SPEC Background). Each re-review costs one AI credit, same as a first review.

---

## Pattern precedents

| Pattern | Precedent file:line | Used for |
|---|---|---|
| Rescore checkbox + `candidatesToScoreCount`/`shortfall` math + Statement block | `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx:35-41,117-151,168-206` | Item 1 modal (SPEC 1.1–1.4) — the pinned analog |
| Info-icon + `Tooltip`-wrapped `Styled.Info` (two usages) | `app/javascript/ats/src/components/modals/CustomQuestionModal/index.js:11,192-199,222-231,254-273` | Item 1 overestimate info block (SPEC 1.3) |
| Hiring-team recipient resolution (`.actives`, `.map`→`{name,email}`, `return unless recipients.any?`) | `app/mailers/job_application_mailer.rb:19,21,28-32` | Item 1 mailer (SPEC 1.6) |
| `params.require(:x).require(:rescore_requested)` (Rails `require` treats `false` as present) | `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb:77-86` | Item 2 controller strong-param (SPEC 2.2) |
| Gate condition `active_ai_summary && !job_application.ai_summary_rescore_requested` | `app/interactors/create_bulk_ai_summary_generation.rb:45` | Item 2 interactor gate (SPEC 2.1) — the ONE copied line |
| Interactor spec `true`/`false` rescore assertion pairs | `spec/interactors/create_bulk_ai_summary_generation_spec.rb:74-113` | Item 2 interactor spec (SPEC 2.8) |
| `type: :controller` spec setup (Devise, Flipper, credits, org_user) + `raise_error(...)` for strong-param/lookup failure | `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb:5-49,90-99` | Item 2 controller spec (SPEC 2.8) |
| `FormCheckbox` contract (`name`,`label`,`description`,`checked`,`onChange`,`disabled?`) | `app/javascript/ats/src/components/forms/FormCheckbox/index.tsx:5-45` | Item 1 checkbox |

**Conflict check:** No open PR (last 3 weeks) touches any file in this plan. Nearest recent PR is `messaging-improvements` #3035 (email subject lines, merged/open 2026-06-05) — disjoint files. No coordination needed.

---

## Files to create or modify

**Item 1**
1. `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx` — add checkbox, 5-state copy restructure, overestimate info block, Statement block, `rescoreRequested: rescore`.
2. `app/javascript/ats/src/views/jobApplications/RunPlatoReviewAllModal.tsx` — three copy defect fixes (checked-state sentence, zero-state, Statement 2nd sentence).
3. `app/mailers/bulk_all_stages_ai_summary_result_mailer.rb` — `complete` + `failed` → active hiring-team recipients.
4. `spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb` — extend AND reconcile the pre-existing stale spec.

**Item 2**
5. `app/interactors/create_ai_summary_generation.rb` — one gate condition at `:36`.
6. `app/controllers/api/v1/ai_job_application_summaries_controller.rb` — add `ai_job_application_summary_params`; set attribute before interactor.
7. `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts` — `GenerateParams.rescoreRequested: boolean` (required).
8. `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` — `handleGenerate(rescoreRequested)`, 4 callsites, `:247` gating change.
9. `app/javascript/ats/src/views/jobApplications/AiSummaryState.tsx` — **DELETE**.
10. `spec/interactors/create_ai_summary_generation_spec.rb` — **CREATE**.
11. `spec/controllers/api/v1/ai_job_application_summaries_controller_spec.rb` — **CREATE**.

Scope: **9 modified, 2 created, 1 deleted (12 touched).** ~250 net LOC (most of it the two new specs + the modal copy restructure).

---

## Ordering constraints (READ BEFORE SEQUENCING)

- **HARD (TypeScript compile):** Task F3 (add required `rescoreRequested` to `GenerateParams`), Task F4 (`PlatoTab.tsx` callsites), and Task F5 (delete `AiSummaryState.tsx`) MUST land together in one atomic unit. The moment `rescoreRequested: boolean` becomes a **required** field (no `?`), every `generate({...})` callsite that omits it is a compile error. Verified consumers of `useGenerateAiSummary`: only `PlatoTab.tsx` (updated in F4) and `AiSummaryState.tsx` (deleted in F5) — no third survivor (grep confirmed zero other `generate({ jobApplicationId` callsites and zero external `AiSummaryState` references in `app/` or `cypress/`). Do NOT do F3 alone and leave the tree in a non-compiling state.
- **CORRECTNESS (same-branch, ship together):** the `RunPlatoReviewAllModal` Statement first sentence ("The hiring team gets an email with the final count when it's done.") is only TRUE after the Task B1 mailer change. Keep A2 (modal) and B1 (mailer) in the same merge.
- **INDEPENDENT:** Item 1 and Item 2 are otherwise independent and may be implemented in either order. The interactor gate (B4) alone is inert without the controller param (B6) + frontend (F3/F4), but all ship in one branch, so there is no runtime-ordering hazard within the branch. The controller requiring the param and the frontend sending it are both in this branch — do not split them across merges.

---

## Backend changes

### Task B1 — `bulk_all_stages_ai_summary_result_mailer.rb` (SPEC 1.6)
*Read first: `cursor_rules/backend/_base.md` (bare guard returns §rule 8 of core; single quotes; variable naming §9), `cursor_rules/core_critical_rules.md` rules 8 & 11.*

Apply the **same** change to both `complete` and `failed`. In each method, after the `job_link` assignment and before `message_params`, insert the recipient resolution; then replace the `to:` line.

- [ ] **B1.1** In `complete`, insert before `message_params = {`:
  ```ruby
  recipients = @job.organization_users.actives.includes(:user)
  return unless recipients.any?

  to_recipients = recipients.map do |organization_user|
    { name: "#{organization_user.user.first_name} #{organization_user.user.last_name}".strip, email: organization_user.user.email }
  end
  ```
- [ ] **B1.2** In `complete`, replace `to: [{ name: @user.full_name, email: @user.email }],` with `to: to_recipients,`.
- [ ] **B1.3** In `failed`, insert the identical `recipients`/`to_recipients` block (same code as B1.1) before its `message_params = {`.
- [ ] **B1.4** In `failed`, replace its `to: [{ name: @user.full_name, email: @user.email }],` with `to: to_recipients,`.
- [ ] **B1.5** In BOTH methods, delete the `@user = User.find(user_id)` line and remove the `user_first_name: @user.first_name,` entry from the `variables` hash (owner-ruled 2026-07-11: greeting removed entirely). The `user_id` parameter STAYS in both method signatures — callers are unchanged, the argument is simply no longer read. Do not touch subject, tags, template, other `variables` entries, or `Emails::SendTemplateEmail.new(message_params).send`.
- [ ] **B1.6** polymer-mail repo (`/Users/jessica/wrk/wrk-corp/polymer-mail`): delete the `<p>Hi {{user_first_name}},</p>` line (line 30 in both files) from `transactional/user-facing/user-bulk-all-stages-ai-summary-complete.mjml` and `transactional/user-facing/user-bulk-all-stages-ai-summary-failed.mjml`. No replacement greeting (matches `new-application-received.mjml` and the other multi-recipient analogs, which have none). Do NOT touch `user-bulk-ai-summary-complete.mjml` / `user-bulk-ai-summary-failed.mjml` (per-stage, single recipient). NOTE for the final report: Jessica manually pastes both updated templates into Mailgun after merge.

Notes: `@job.organization_users` is `has_many through: :hiring_team_memberships` (`app/models/job.rb:48`); `actives` = `where(is_active: true)` (`app/models/organization_user.rb:48`). Variable named `organization_user` per rule 9 (the analog names the block var `recipient`; use `organization_user`). `.includes(:user)` avoids N+1 (the analog uses it). This deliberately OMITS `.receives_new_job_application_emails` — owner-ruled (no Plato-bulk opt-out key exists); do not add any opt-out filter. E1 is RESOLVED (owner-ruled 2026-07-11): greeting removed entirely — one team-wide email, no `user_first_name`, template greeting line deleted (B1.5/B1.6). Do NOT design any per-recipient send.

### Task B4 — `create_ai_summary_generation.rb` (SPEC 2.1) — the ONE gate
*Read first: `cursor_rules/backend/interactors/` (if present), `cursor_rules/core_critical_rules.md` rules 8, 11, 25.*

- [ ] **B4.1** At `create_ai_summary_generation.rb:36`, change `if active_ai_summary` to `if active_ai_summary && !job_application.ai_summary_rescore_requested`. This is identical to `create_bulk_ai_summary_generation.rb:45`.
- [ ] **B4.2** Change NOTHING else in this file. Keep the `ap` debug lines, the `active_ai_summary` query (30-34), the `validation_result.textract_pending` branch (41-53), the `pending` build + `GenerateAiJobApplicationSummaryJob.perform_later` enqueue (55-72), and the `requested_by_organization_user_id` set. Do NOT port the bulk interactor's staleness-refresh block (`create_bulk_ai_summary_generation.rb:40-43`) — guardrail 1. The `textract_result.rb:68` succeeded-and-not-stale return self-resolves (the new pending row becomes `latest_ai_job_application_summary`); no other gate changes (SPEC 2.1 lists all eight untouched gates).

### Task B6 — `ai_job_application_summaries_controller.rb` (SPEC 2.2) — param boundary
*Read first: `cursor_rules/backend/controllers/` (+ `_base`), `cursor_rules/core_critical_rules.md` rules 1 (no begin block), 5 (one params method).*

- [ ] **B6.1** Add ONE private params method (core rule 5) at the bottom of the controller:
  ```ruby
  private

  def ai_job_application_summary_params
    params.require(:ai_job_application_summary).require(:rescore_requested)
  end
  ```
  This returns the required scalar value (Rails `require` special-cases `false` as present — the same reason the bulk controller's `require` works). Do not add `.permit` — the scalar `.require().require()` is the owner-approved shape.
- [ ] **B6.2** In `create`, inside the `exists(...) do |job_application|` block, set the attribute on the record IMMEDIATELY BEFORE `result = CreateAiSummaryGeneration.call(`:
  ```ruby
  job_application.ai_summary_rescore_requested = ai_job_application_summary_params
  ```
  This placement (after `ValidateAiSummaryGeneration`, right before `CreateAiSummaryGeneration`) matches the bulk path and is owner-approved (SPEC 2.2; the after-validation ordering was reviewed as L4 and accepted). No begin block. Do not touch `show`, the `exists`/`authorize` calls, or the render branches.

---

## Frontend changes

### Task A1 — `BulkGenerateAiSummariesConfirmModal.tsx` full restructure (SPEC 1.1–1.4)
*Read first: `cursor_rules/frontend/_base.md`, `cursor_rules/frontend/modals/`, `cursor_rules/frontend/ui_styling.md`, `cursor_rules/frontend/forms/`, `cursor_rules/core_critical_rules.md` rules 9, 13; pipeline known-failure #1 (theme utilities are complete CSS declarations — use `${t.text.xs};` standalone, NEVER inside `font-size:`).*

- [ ] **A1.1 Imports.** Add `import FormCheckbox from "@ats/src/components/forms/FormCheckbox";` and `import Tooltip from "@ats/src/components/shared/Tooltip";`. `Icon` (line 7) and `FormContainer` (line 8) are already imported.
- [ ] **A1.2 State.** After `const [errors, setErrors] = React.useState([]);` add `const [rescore, setRescore] = React.useState(false);`.
- [ ] **A1.3 Credit math.** Replace `const shortfall = Math.max(0, processableCount - available);` (line 51) and the comment above it with:
  ```tsx
  const candidatesToScoreCount = rescore ? candidatesCount : processableCount;
  const shortfall = Math.max(0, candidatesToScoreCount - available);
  ```
- [ ] **A1.4 Mutation flag.** In the `bulkGenerate({ ... })` call, change `rescoreRequested: false,` (line 74) to `rescoreRequested: rescore,`. Change nothing else in the call, its `onSuccess`/`onError`, or the `trackEvent` name/payload (SPEC 1.8 — trackEvent untouched).
- [ ] **A1.5 Delete old copy machinery.** Delete the `shortfallText` fragment (lines 105-110) and the entire four-branch `instructions` const (lines 112-150).
- [ ] **A1.6 New body copy const.** Add a `creditCopy` fragment and a `bodyCopy` precedence node (this replaces `instructions`). Type it EXACTLY:
  ```tsx
  const creditCopy = (
    <>
      Each successful review uses one AI credit
      {shortfall > 0 ? (
        <>
          . You are short <b>{shortfall}</b> credit{shortfall === 1 ? "" : "s"}. The first{" "}
          {available} candidate{available === 1 ? "" : "s"} will get reviews generated; the rest
          will be skipped.
        </>
      ) : (
        <>
          , so running this uses up to <b>{candidatesToScoreCount}</b> credit
          {candidatesToScoreCount === 1 ? "" : "s"} from your balance of <b>{available}</b> available.
        </>
      )}
    </>
  );

  let bodyCopy: React.ReactNode;
  if (candidatesCount === 0) {
    // State 1 — no selection (kept VERBATIM from today, SPEC 1.2/1.8)
    bodyCopy = (
      <>
        <span>No candidates selected.</span> Use the checkboxes next to the candidate names to select
        the candidates to generate reviews for. To <b>select all candidates</b> within this hiring
        stage, use the checkbox next to the stage name.
      </>
    );
  } else if (!rescore && processableCount === 0) {
    // State 2 — unchecked, zero processable (numeric 0, no credit sentence)
    bodyCopy = (
      <>
        0 of the {candidatesCount} candidates selected from this hiring stage don't have a Plato
        review yet. Unless you select re-review below, no candidates will be reviewed.
      </>
    );
  } else if (!rescore) {
    // State 3 — unchecked, processable ("Up to " prefix only when inexact)
    bodyCopy = (
      <>
        {isProcessableCountExact ? "" : "Up to "}
        {processableCount} of the {candidatesCount} candidates selected from this hiring stage don't
        have a Plato review yet. {creditCopy}
      </>
    );
  } else {
    // State 4 — checked (leading "The"; exact count even mid-load; no info block)
    bodyCopy = (
      <>
        The {candidatesCount} candidates selected from this hiring stage will be reviewed, including
        candidates that already have a review. {creditCopy}
      </>
    );
  }
  ```
  Precedence order is exactly 1→2→3→4 (SPEC 1.2). Numeric `0` in state 2, never the word. State 4 keeps the leading "The" (owner-ruled divergence from all-stages — do not remove).
- [ ] **A1.7 Submit button disabled condition.** In `modalButtons`, change `disabled={isLoading || processableCount === 0}` (line 160) to:
  ```tsx
  disabled={isLoading || candidatesCount === 0 || (!rescore && processableCount === 0)}
  ```
  Keep `loading={isLoading}` (the `loading`+`disabled` pairing is intact — known-failure #11). This enables the button in states 3 and 4, disables in states 1 and 2 (SPEC 1.2).
- [ ] **A1.8 Return JSX restructure.** Replace the current `return (...)` (lines 177-198) with the analog-style layout — Body, conditional info block, checkbox, Statement all as direct children of `CenterModal`, then an EMPTY `FormContainer` at the end:
  ```tsx
  return (
    <CenterModal headerTitleText="Review candidates" onCancel={handleOnCancel}>
      <Styled.Instructions>{bodyCopy}</Styled.Instructions>
      {!isProcessableCountExact && !rescore && (
        <Tooltip label="This is not an exact count of candidates without a review. If fewer candidates than stated above are unreviewed, only those unreviewed candidates will be reviewed, and fewer credits will be consumed.">
          <Styled.Info>
            <Icon name="alert-circle" />
            <span>This count may be an overestimate.</span>
          </Styled.Info>
        </Tooltip>
      )}
      <Styled.RescoreCheckbox>
        <FormCheckbox
          name="rescore"
          label="Also re-review candidates that already have a review"
          description="Recommended if you've changed the candidate requirements in the job description."
          checked={rescore}
          onChange={() => setRescore((currentRescore) => !currentRescore)}
          disabled={candidatesCount === 0}
        />
      </Styled.RescoreCheckbox>
      <Styled.Statement>
        <Icon name="mail" />
        <span>
          You will receive an email with the final count when it's done. Candidates without a
          resume, one that's still processing, or those already part of another bulk operation are
          skipped.
        </span>
      </Styled.Statement>
      <FormContainer errors={errors} buttons={modalButtons} onSubmit={handleOnConfirm} />
    </CenterModal>
  );
  ```
  - Body wrapper stays `Styled.Instructions` (see "Decision D1" in Risks — resolves open review LOW L1; keeps State 1 byte-identical and its bold `<span>`). Do NOT introduce a new `Styled.Body`.
  - Overestimate info block renders ONLY when `!isProcessableCountExact && !rescore` (SPEC 1.3), directly beneath the body copy. Short message and Tooltip `label` are verbatim above.
  - Checkbox `disabled={candidatesCount === 0}` renders it visible-but-not-checkable in the no-selection state (SPEC 1.1). `onChange` toggles (matches analog `RunPlatoReviewAllModal.tsx:141`).
  - The old `Styled.Caveat`, `Styled.Callout`, and the `FormContainer` children are gone.
- [ ] **A1.9 Styled components.** In the `Styled` block: DELETE `Styled.Caveat` (236-248) and `Styled.Callout` (250-270). KEEP `Styled.Instructions` and `Styled.ButtonContainer`. ADD three, each copied verbatim as pinned:
  ```tsx
  Styled.RescoreCheckbox = styled.div((props) => {
    const t: any = props.theme;
    return css`
      label: BulkGenerateAiSummariesConfirmModal_RescoreCheckbox;
      ${t.mt(4)}
    `;
  });

  Styled.Info = styled.div((props) => {
    const t: any = props.theme;
    return css`
      label: BulkGenerateAiSummariesConfirmModal_Info;
      ${[t.text.xs, t.mt(-1), t.mb(5)]}
      color: ${t.dark ? t.color.gray[400] : t.color.gray[600]};
      display: flex;
      align-items: center;
      line-height: 1.3;

      svg {
        ${[t.h(6), t.w(4), t.mr(1)]}
        min-width: 16px;
      }

      &:hover {
        cursor: text;
      }
    `;
  });

  Styled.Statement = styled.div((props) => {
    const t: any = props.theme;
    return css`
      label: BulkGenerateAiSummariesConfirmModal_Statement;
      ${[t.mt(4), t.p(3), t.rounded.md]}
      display: flex;
      gap: 0.625rem;
      border: 1px solid ${t.dark ? t.color.gray[700] : t.color.gray[200]};
      color: ${t.dark ? t.color.gray[400] : t.color.gray[500]};
      line-height: 1.5;
      ${t.text.sm}

      svg {
        flex-shrink: 0;
        margin-top: 0.0625rem;
        width: 1rem;
        height: 1rem;
        color: ${t.dark ? t.color.gray[500] : t.color.gray[400]};
      }
    `;
  });
  ```
  `Styled.Info` copied verbatim from `CustomQuestionModal` `Styled.Info` (`:254-273`); `Styled.RescoreCheckbox` and `Styled.Statement` from `RunPlatoReviewAllModal` (`:178-184`, `:186-206`) — with the emotion `label:` renamed to the `BulkGenerateAiSummariesConfirmModal_*` names pinned in SPEC 1.1/1.3/1.4.

### Task A2 — `RunPlatoReviewAllModal.tsx` three defect fixes (SPEC 1.5)
*Read first: same frontend rules as A1.*

- [ ] **A2.1 Extract the credit sentence** so it can be reused across the checked and normal branches. Above the `return`, add:
  ```tsx
  const creditSentence = (
    <>
      Each successful review uses one AI credit
      {shortfall > 0 && candidatesToScoreCount > 0 ? (
        <>
          . You are short <b>{shortfall}</b> credit{shortfall === 1 ? "" : "s"}. The first{" "}
          {available} candidate{available === 1 ? "" : "s"} will get reviews generated; the rest
          will be skipped.
        </>
      ) : (
        <>
          , so running this uses up to <b>{candidatesToScoreCount}</b> credit
          {candidatesToScoreCount === 1 ? "" : "s"} from your balance of <b>{available}</b> available.
        </>
      )}
    </>
  );
  ```
  This is the EXACT current credit copy (lines 120-132) lifted unchanged — SPEC says the credit sentence stays unchanged.
- [ ] **A2.2 Replace the `Styled.Body` contents** (current lines 117-133) with a three-way precedence node:
  ```tsx
  <Styled.Body>
    {rescore ? (
      <>
        {candidatesCount} candidate{candidatesCount === 1 ? "" : "s"} in this job will be reviewed,
        including candidates that already have a review. {creditSentence}
      </>
    ) : candidatesToScoreCount === 0 ? (
      <>
        0 candidates in this job don't have a Plato review yet. Unless you select re-review below, no
        candidates will be reviewed.
      </>
    ) : (
      <>
        {candidatesToScoreCount} candidate{candidatesToScoreCount === 1 ? "" : "s"} in this job
        {candidatesToScoreCount === 1 ? " doesn't" : " don't"} have a Plato review yet. {creditSentence}
      </>
    )}
  </Styled.Body>
  ```
  - Checked branch: NO leading "The" (owner-ruled divergence from the per-stage sentence — SPEC 1.5). Credit sentence follows, unchanged.
  - Zero branch (unchecked, count 0): numeric `0`, no credit sentence. Button stays disabled via the existing `candidatesToScoreCount === 0` condition in `modalButtons` (unchanged).
  - Else branch: today's exact wording.
- [ ] **A2.3 Statement second sentence.** In `Styled.Statement` (lines 147-150), keep the first sentence verbatim ("The hiring team gets an email with the final count when it's done.") and replace the second sentence so the whole span reads:
  ```tsx
  <span>
    The hiring team gets an email with the final count when it's done. Candidates without a
    resume, one that's still processing, or those already part of another bulk operation are
    skipped.
  </span>
  ```
- [ ] **A2.4** Change NOTHING else — not the checkbox, hooks, `trackEvent`, button props, or styled components (SPEC 1.5 last bullet).

### Task F3 — `useAiJobApplicationSummary.ts` hook param (SPEC 2.3) [atomic with F4, F5]
*Read first: `cursor_rules/frontend/react_query/`, `cursor_rules/core_critical_rules.md` rules 7, 9, 10.*

- [ ] **F3.1** In `GenerateParams`, add `rescoreRequested: boolean;` — REQUIRED, no `?` marker:
  ```ts
  interface GenerateParams {
    jobApplicationId: number;
    rescoreRequested: boolean;
  }
  ```
  No other change — it rides into the existing `variables: { aiJobApplicationSummary: params }` POST body automatically (becomes `rescore_requested` via the API layer). Do not touch `generateAiSummary`, `useGenerateAiSummary`'s invalidations, `getAiJobApplicationSummary`, or `useAiJobApplicationSummary`.

### Task F4 — `PlatoTab.tsx` callsite wiring + gating (SPEC 2.4, 2.5) [atomic with F3, F5]
*Read first: same frontend rules as A1; `cursor_rules/core_critical_rules.md` rule 13; pipeline known-failure #11 (`loading`+`disabled` pairing).*

- [ ] **F4.1 `handleGenerate` signature.** Change `const handleGenerate = () => {` (line 73) to `const handleGenerate = (rescoreRequested: boolean) => {` — required param, NO default.
- [ ] **F4.2 Mutation call.** Inside `handleGenerate`, change `generate({ jobApplicationId: jobApplication.id }, {` (line 74-75) to `generate({ jobApplicationId: jobApplication.id, rescoreRequested }, {`. Leave `onSuccess`/`onError` unchanged.
- [ ] **F4.3 Regenerate `onConfirm`.** In `handleClickRegenerate`'s `ConfirmationModal`, change the `onConfirm` body (lines 106-109) so it calls `handleGenerate(true)` after the existing `removeModal()`:
  ```tsx
  onConfirm={() => {
    removeModal();
    handleGenerate(true);
  }}
  ```
- [ ] **F4.4 Three empty-state callsites → arrow-wrapped `false`.** `PlatoTabEmptyState`'s `onClick?: () => void` is invoked with the DOM click event; a bare `onClick={handleGenerate}` would deliver the event as a truthy `rescoreRequested`. Arrow-wrap all three:
  - bulkQueued (line 192): `onClick={handleGenerate}` → `onClick={() => handleGenerate(false)}`
  - failed (line 203): `onClick={handleGenerate}` → `onClick={() => handleGenerate(false)}`
  - ready/noCredits, final `else` (line 233): `onClick={handleGenerate}` → `onClick={() => handleGenerate(false)}`
  - Do NOT touch the noResume callsite (line 222) — it uses `handleNavigateToResumeTab`, not `handleGenerate`.
- [ ] **F4.5 Regenerate gating.** Change the header-right condition at line 247 from `} else if (statusValue === "current" && fullSummary?.stale) {` to `} else if (statusValue === "current") {`. Everything inside the branch stays byte-for-byte: the `isLoadingCredits || totalRemaining > 0` credits check, the Regenerate `Button` with `loading={buttonLoading} disabled={buttonLoading}` (pairing intact), and both `PlatoHeaderNavButton` Buy-credits fallbacks. Do not touch the `regenerating` branch above it.

### Task F5 — delete `AiSummaryState.tsx` (SPEC 2.6) [atomic with F3, F4]
- [ ] **F5.1** `git rm app/javascript/ats/src/views/jobApplications/AiSummaryState.tsx`. Verified dead: zero references in `app/` or `cypress/` (its only external hazard was its own `generate({ jobApplicationId })` call, which would break compile once F3 makes `rescoreRequested` required). Delete ONLY this file (known-failure #23 — scoped deletion).
- [ ] **F5.2** After F3–F5, run the TypeScript compile (`yarn tsc --noEmit` or the project's type-check) to confirm no remaining `generate({...})` callsite lacks `rescoreRequested`.

---

## Validation and constraints

- **Where required-ness lives:** the `rescore_requested` boolean is enforced at the controller strong-params boundary (`params.require(:ai_job_application_summary).require(:rescore_requested)`), NOT in the interactor — interactors do not enforce parameters (owner rationale, SPEC 2.2). Rails `require` treats `false` as present, so `rescore_requested: false` passes and only a truly-absent key raises `ActionController::ParameterMissing`.
- **Frontend always sends the boolean** — literal `false` on plain Generate (all three empty-state callsites), `true` from Regenerate. No fabricated fallback anywhere (core rule 10 / known-failure #13); the field is required in `GenerateParams` (F3) so the compiler enforces presence.
- **Mailer guard:** `return unless recipients.any?` is a bare guard (core rule 8) in both methods; `actives` scope enforces active-only; no opt-out filter (none exists).
- **Interactor:** no `update_columns` introduced (rule 25); the single gate condition is the only change (rules 10 & 23 — no add/remove beyond scope).

---

## Test plan (backend only — NO frontend tests, owner-ruled, guardrail 3)

### Task T1 — extend + reconcile `spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb` (SPEC 1.7)
*Read first: `cursor_rules/core_critical_rules.md` rules 8, 11, 26 (no ghost tests); the spec is `type: :mailer`. Helper source: `spec/support/ai_credits_test_helpers.rb`.*

This spec is STALE against the current mailer and cannot pass as-is — reconcile ALL of the following, do not layer recipient assertions on top of failing expectations:

- [ ] **T1.1 Recipient fixtures.** Add active + inactive hiring-team members and attach them to the job:
  ```ruby
  let(:active_member) { create_credit_test_organization_user(organization, role: :org_admin) }
  let(:inactive_member) { create_credit_test_organization_user(organization, role: :org_admin) }

  before do
    job.organization_users << active_member
    job.organization_users << inactive_member
    inactive_member.update!(is_active: false)
  end
  ```
- [ ] **T1.2 `#complete` arity + assertions.** Change the call from `complete(user.id, job.id, 5, 1, 2)` (5 args → `ArgumentError`) to `complete(user.id, job.id, 5, 1, 2, 8)` (6-arg signature adds `total`). Fix the assertions to match the real mailer:
  - subject → `"Your Plato reviews for #{job.title} are ready"` (was "Your AI summaries for …").
  - tags → `['polymer', 'user-facing']` (was `[..., 'ai-summaries']`).
  - Replace `expect(params[:to].first[:email]).to eq(user.email)` with:
    ```ruby
    emails = params[:to].map { |r| r[:email] }
    expect(emails).to include(active_member.user.email)
    expect(emails).not_to include(inactive_member.user.email)
    ```
  - Keep the succeeded/failed/skipped/job_link assertions.
- [ ] **T1.3 `#failed` assertions.** Keep the `failed(user.id, job.id, 10)` call (3-arg signature is correct). Fix:
  - subject → `"We couldn't complete your Plato reviews for #{job.title}"` (was "We couldn't generate AI summaries for …").
  - Replace the single-recipient `to` assertion with the same active-present / inactive-absent pair from T1.2.
- [ ] **T1.4 Falsifiability.** The recipient assertions must fail if B1 is reverted (mailer sends only to the triggering user) — `active_member` is a distinct user explicitly added to the hiring team, so `include(active_member.user.email)` is falsifiable (core rule 26).
- [ ] **T1.5 Greeting variable removed.** In both `#complete` and `#failed` examples, assert the captured `message_params[:variables]` does NOT contain `user_first_name` (SPEC 1.7(e)) — falsifiable by reverting B1.5.

### Task T2 — CREATE `spec/interactors/create_ai_summary_generation_spec.rb` (SPEC 2.8)
*Read first: mirror `spec/interactors/create_bulk_ai_summary_generation_spec.rb:1-35,74-113`; `cursor_rules` interactor rules; core rule 26.*

- [ ] **T2.1 Setup** copied from the bulk interactor spec: `include ActiveJob::TestHelper`; the `around` queue-adapter block; `let(:organization)`, `let(:org_user)`, `let(:user)` (with `u.update(current_organization_user: org_user)`), `let(:job)`, `let(:job_application)` (with a succeeded `TextractResult`), `let(:textract_result)`.
- [ ] **T2.2 The double MUST stub `textract_pending: false`** (SPEC A3 — the single-send interactor reads `validation_result.textract_pending` at `:41` on the fall-through path; the bulk spec's double omits it and would raise):
  ```ruby
  let(:validation_result) { double('validation_result', textract_result: textract_result, textract_pending: false) }
  ```
- [ ] **T2.3 Rescore-true path** — builds a NEW pending row, leaves the existing succeeded row untouched, AND enqueues `GenerateAiJobApplicationSummaryJob` (this last assertion is the single-send difference from the bulk interactor, which does not enqueue):
  ```ruby
  it 'builds a new pending row and enqueues GenerateAiJobApplicationSummaryJob when rescore requested' do
    existing = job_application.ai_job_application_summaries.create!(textract_result: textract_result, status: :succeeded, stale: false)
    job_application.ai_summary_rescore_requested = true

    expect {
      result = described_class.call(job_application: job_application, validation_result: validation_result, user: user)
      expect(result.success?).to be true
      expect(result.ai_summary.id).not_to eq(existing.id)
      expect(result.ai_summary.status).to eq('pending')
      expect(existing.reload.status).to eq('succeeded')
      expect(existing.reload.stale).to be false
    }.to have_enqueued_job(GenerateAiJobApplicationSummaryJob)
  end
  ```
- [ ] **T2.4 Rescore-false path** — returns the existing summary and enqueues nothing:
  ```ruby
  it 'returns the existing summary and enqueues nothing when rescore not requested' do
    existing = job_application.ai_job_application_summaries.create!(textract_result: textract_result, status: :succeeded, stale: false)
    job_application.ai_summary_rescore_requested = false

    expect {
      result = described_class.call(job_application: job_application, validation_result: validation_result, user: user)
      expect(result.ai_summary.id).to eq(existing.id)
    }.not_to have_enqueued_job(GenerateAiJobApplicationSummaryJob)
  end
  ```
- [ ] **T2.5 Falsifiability.** Reverting B4 (gate) must break T2.3 (rescue-true would return `existing` and enqueue nothing → both the id-inequality and `have_enqueued_job` fail). Do NOT add a ghost assertion (core rule 26).

### Task T3 — CREATE `spec/controllers/api/v1/ai_job_application_summaries_controller_spec.rb` (SPEC 2.8)
*Read first: mirror `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb:5-49`; `cursor_rules` request/controller spec rules; core rule 26; known-failure #7 (stubs must not mask param-type mismatch).*

- [ ] **T3.1 Setup** copied from the bulk controller spec: `type: :controller`, `include ActiveJob::TestHelper`, `include Devise::Test::ControllerHelpers`, the `around` adapter block, the `let(:organization)/(:user)/(:organization_user)/(:job_record)` blocks, and the `before` block (Flipper enable, credit balance, `current_user` stubs). Reuse the `job_application_with_textract` helper.
- [ ] **T3.2 Missing-param rejection.** Because the param `require` sits AFTER `ValidateAiSummaryGeneration`, stub Validate to succeed so control reaches the require; then a request whose `ai_job_application_summary` lacks `rescore_requested` raises `ActionController::ParameterMissing` (the base controllers do NOT rescue it — verified; mirrors the bulk spec's `raise_error(ActiveRecord::RecordNotFound)` style):
  ```ruby
  it 'rejects a request without rescore_requested' do
    job_application = job_application_with_textract
    allow(ValidateAiSummaryGeneration).to receive(:call)
      .and_return(double(success?: true, textract_result: job_application.latest_textract_result, textract_pending: false))

    expect {
      post :create, params: { job_application_id: job_application.id, ai_job_application_summary: {} }, format: :json
    }.to raise_error(ActionController::ParameterMissing)
  end
  ```
- [ ] **T3.3 Value threads onto the record.** Stub both interactors; capture the `job_application` passed to `CreateAiSummaryGeneration` and assert the attribute is set; return a real persisted `AiJobApplicationSummary` so `render_one` serializes cleanly:
  ```ruby
  it 'threads rescore_requested onto the job_application before CreateAiSummaryGeneration' do
    job_application = job_application_with_textract
    ai_job_application_summary = job_application.ai_job_application_summaries.create!(
      textract_result: job_application.latest_textract_result, status: :pending
    )
    allow(ValidateAiSummaryGeneration).to receive(:call)
      .and_return(double(success?: true, textract_result: job_application.latest_textract_result, textract_pending: false))
    captured_job_application = nil
    allow(CreateAiSummaryGeneration).to receive(:call) do |args|
      captured_job_application = args[:job_application]
      double(success?: true, ai_summary: ai_job_application_summary)
    end

    post :create, params: {
      job_application_id: job_application.id,
      ai_job_application_summary: { rescore_requested: true }
    }, format: :json

    expect(response).to have_http_status(:ok)
    expect(captured_job_application.ai_summary_rescore_requested).to be true
  end
  ```
- [ ] **T3.4 Falsifiability.** T3.3 fails if B6.2 (the attribute-set line) is removed (attribute stays `false`); T3.2 fails if B6.1 (the `require`) is removed. Both are falsifiable (core rule 26). The stubs pass `rescore_requested` as the real param shape — no type mismatch masked (known-failure #7).

### Existing tests NOT to modify (source of truth)
- `spec/interactors/create_bulk_ai_summary_generation_spec.rb`, `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb`, `queue_bulk_ai_summary_jobs_spec.rb` already cover the shared `rescore_requested` enqueue threading — do not touch (SPEC 1.7/1.8).
- No Cypress tests are added or modified (owner-ruled — no frontend tests).

### Running the specs
- [ ] **T4** After implementation, run: `bundle exec rspec spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb spec/interactors/create_ai_summary_generation_spec.rb spec/controllers/api/v1/ai_job_application_summaries_controller_spec.rb`. All green before commit. (Commit only when Jessica asks; run inflow-ats commits detached, never `--no-verify`.)

---

## Documentation impact

No docs pages, README, or `cursor_rules` changes. Template sources ARE part of this plan (B1.6): the two all-stages `.mjml` files in the polymer-mail repo lose their greeting line; Jessica manually pastes both into Mailgun after merge (the Mailgun-hosted copies are not touched by code).

---

## Risks and open questions

- **D1 (design decision, resolves review LOW L1):** the per-stage body-copy wrapper stays `Styled.Instructions` (not a new analog-style `Styled.Body`). Rationale: SPEC leaves the wrapper unpinned, but SPEC 1.2/1.8 require State 1 (no-selection) to render byte-identically, including its bold `<span>` which relies on `Styled.Instructions`'s `span { font-weight: bold }`. Reusing `Styled.Instructions` satisfies that constraint and avoids inventing an unpinned component. Visual differs slightly from the all-stages `Styled.Body` (mb vs mt/gray/line-height); acceptable and pin-faithful. Flagged for reviewer/owner visibility.
- **E1 RESOLVED (owner-ruled 2026-07-11):** greeting removed entirely. B1.5 deletes the `@user` load and the `user_first_name` variable; B1.6 deletes the template greeting lines in polymer-mail. One team-wide email, no personalization. Do NOT design a per-recipient send.
- **T3 serialization risk (low):** T3.3 returns a real `AiJobApplicationSummary` via `render_one`; if the serializer needs associations the fixture lacks, build them from `job_application_with_textract` (which attaches a resume + succeeded textract). Verify at runtime.
- **`ActionController::ParameterMissing` handling (verified, low):** confirmed neither `Api::V1::BaseController` nor `ApplicationController` rescues `ParameterMissing` (only `Pundit::NotAuthorizedError`), so T3.2's `raise_error(ActionController::ParameterMissing)` is correct. If a future base-controller rescue is added that renders 400, switch T3.2 to `expect(response).to have_http_status(:bad_request)`.
- **Guardrail reminders for the fix/impl agent:** Item 2 interactors are NOT a whole-file analog — copy ONLY the gate condition (guardrail 1). Item 1 copy is pinned verbatim — verify against the SPEC's pinned strings, not a fresh reading of the analog (guardrail 2). No frontend tests (guardrail 3). Do not touch the explicitly-untouched items in SPEC 1.8 / 2.1.

---

## Estimated scope

- **Modified:** 9 files (2 modals, 1 mailer, 1 interactor, 1 controller, 1 hook, 1 component `PlatoTab.tsx`, 1 mailer spec).
- **Created:** 2 files (interactor spec, controller spec).
- **Deleted:** 1 file (`AiSummaryState.tsx`, 222 lines).
- **Net LOC:** roughly +330 / −270 (≈ +60 net once the `AiSummaryState.tsx` deletion and the modal copy churn net out); the two new specs (~120 lines) are the bulk of the additions.
