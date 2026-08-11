# Approved decisions — Plato rescore + touchups spec (started 2026-07-11)

Decisions explicitly confirmed by Jessica, one per section. Pending items are NOT in this file.

## Target worktree

The work targets worktree `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings`, branch `job-criteria-settings-qa`. Confirmed: "Yes, it is."

## Item 1 — per-stage checkbox copy

The per-stage checkbox in `BulkGenerateAiSummariesConfirmModal` reuses the all-stages `RunPlatoReviewAllModal` strings verbatim — label "Also re-review candidates that already have a review", description "Recommended if you've changed the candidate requirements in the job description." Users will read it as scoped to the candidates they selected; nothing in the strings says whole-job. Confirmed: "Yes, people will assume it applies only to the candidates they selected."

## Item 1 — count behavior when checkbox checked

Checkbox checked → the per-stage modal's displayed count, credit math, and shortfall all use `candidatesCount` (the full selection); unchecked → `processableCount` as today. Mirrors all-stages semantics where checked switches the count to the full candidate count. Confirmed: "Yes."

## Item 1 — methodology: mirror the analog, surface only non-mirrorable rows

`RunPlatoReviewAllModal` is the analog for the per-stage checkbox work. Default is to mirror it as completely as possible — structure AND functionality, not one or the other ("copy as much as you can"). Instead of one-at-a-time questions per sub-decision, Claude reviews the analog, builds the structural manifest, and brings Jessica only the rows that cannot mirror (forced deviations), for her ruling. Confirmed: "review the analog and flag anything you feel might not be able to mirror."

## Item 1 flag A — analog Body copy defect fixed, conditional wording

In `RunPlatoReviewAllModal`, the Body sentence "{candidatesToScoreCount} candidate(s) in this job don't have a Plato review yet" is a defect when the rescore checkbox is checked (the count then includes already-reviewed candidates). Fix is in scope. When `rescore` is checked, the Body's first sentence changes to: "{candidatesToScoreCount} candidate(s) in this job will be reviewed, including candidates that already have a review." The credit sentence that follows stays unchanged. When unchecked, current copy stays. Confirmed: "Change the defect, but your proposed wording is fine."

## Item 1 — copy restructure: per-stage modal replicates the analog copy setup

`BulkGenerateAiSummariesConfirmModal` drops its own copy structure (the four Instructions branches, the Caveat block, the Callout block) and replicates `RunPlatoReviewAllModal`'s setup. Lead sentence: "{processableCount} of the {candidatesCount} candidates selected from this hiring stage don't have a Plato review yet." From there the copy follows the analog verbatim: the credit sentence with its shortfall/normal variants (rescore-aware count), the checkbox, then the analog's Statement block (email note + skip reasons) replacing today's Caveat + Callout. Checked variant (flag-A conditional applied to both modals) — per-stage: "The {candidatesCount} candidates selected from this hiring stage will be reviewed, including candidates that already have a review." (leading "The" — a selection was made); all-stages: "{candidatesCount} candidate(s) in this job will be reviewed, including candidates that already have a review." (NO leading "The" — no selection state exists for the full job) — each followed by the credit sentence. Wording ruled 2026-07-11: "no leading the for the bulk job run". Confirmed via the zero-state exchange ("Would this resolve the situation?" → refined → "Confirm.").

## Item 1 — zero-processable state copy (defect fix in BOTH modals; supersedes the earlier flag-B capture)

When the checkbox is unchecked and the processable count is 0, the count lead sentence STAYS and only the credit sentence is replaced. All-stages: "0 candidates in this job don't have a Plato review yet. Unless you select re-review below, no candidates will be reviewed." Per-stage: "0 of the {candidatesCount} candidates selected from this hiring stage don't have a Plato review yet. Unless you select re-review below, no candidates will be reviewed." Numeric 0, not the word. Button disabled. Checking re-review switches to the standard checked variant (see restructure section) and enables the button. This replaces the analog's current "0 candidates... uses up to 0 credits" rendering and the per-stage "Nothing to generate" branch. Confirmed: "Confirm."

## Item 1 — no-selection branch kept as-is

The per-stage `candidatesCount === 0` branch ("No candidates selected. Use the checkboxes next to the candidate names...") stays exactly as it is today. It renders instead of the analog-style copy whenever nothing is selected; the "Generate reviews" button stays disabled; the rescore checkbox renders disabled — visible but not checkable, same behavior as the button. Only per-stage-only branch surviving the restructure. Confirmed: "Yes, keep it exactly the way it is." + amendment "Confirm. It's the same behavior as the button. Just disable it."

## Item 1 — inexact Select-All caveat: info-icon + tooltip pattern from CustomQuestionModal

The analog cannot be matched here — all-stages counts are exact; a per-stage Select All with unloaded rows is not. When `isProcessableCountExact` is false and the rescore checkbox is unchecked: the lead sentence gets the "Up to" prefix ("Up to {processableCount} of the {candidatesCount} candidates selected from this hiring stage don't have a Plato review yet."), and directly beneath the body copy renders the pattern copied from `CustomQuestionModal` (app/javascript/ats/src/components/modals/CustomQuestionModal/index.js:192-199): `Tooltip`-wrapped `Styled.Info` — `alert-circle` icon + short visible message, longer message in the Tooltip `label` on hover, `Styled.Info` styling copied (`t.text.xs`, muted gray, flex, line-height 1.3).

- Short visible message: "This count may be an overestimate."
- Tooltip label: "This is not an exact count of candidates without a review. If fewer candidates than stated above are unreviewed, only those unreviewed candidates will be reviewed, and fewer credits will be consumed."

When the checkbox is checked, count switches to `candidatesCount` (exact even mid-load) — the "Up to" prefix and the info block both drop. When `isProcessableCountExact` is true, neither renders. Today's gray Caveat box is deleted. Confirmed: "The only issue is the tooltip label" + reworded label + "Yeah, we can go with that."

## Result-email recipients + Statement first sentence (per modal)

All-stages (full job) run: `BulkAllStagesAiSummaryResultMailer` changes — both `complete` and `failed` — to send to every active hiring-team member of the job. Recipients resolved like `JobApplicationMailer#hiring_team_new_job_application` but WITHOUT the preference filter: `job.organization_users.actives`, all in one email's `to:` array. No opt-out (no Plato-bulk preference key exists). The all-stages modal Statement keeps the analog wording "The hiring team gets an email with the final count when it's done." — true after this change.

Per-stage run: `BulkJobApplicationAiSummaryResultMailer` stays exactly as-is — triggering user only (small selections emailing the whole team would feel weird). Per-stage modal Statement first sentence: "You will receive an email with the final count when it's done." Confirmed: "This applies to both complete and failed, yes, and I confirm the per-stage run copy."

## All-stages result email — no greeting, single team-wide send (amends the result-email section; reverses spec-review amendment A1)

The all-stages result email stays ONE email to all active hiring-team members (`job.organization_users.actives` in the `to:` array) — per-recipient loop sends explicitly rejected ("Why should I send a fuck ton of emails when I can only send one?"). The greeting goes away entirely, matching the analog multi-recipient templates (`new-application-received.mjml`, `new-job-application-comment.mjml`, `new-message-received.mjml` — none has a greeting line):

- polymer-mail repo: delete the `<p>Hi {{user_first_name}},</p>` line (line 30) from BOTH `transactional/user-facing/user-bulk-all-stages-ai-summary-complete.mjml` and `user-bulk-all-stages-ai-summary-failed.mjml`. No replacement greeting. Jessica pastes both updated templates into Mailgun (manual step, recorded in spec).
- `BulkAllStagesAiSummaryResultMailer#complete`/`#failed`: drop `user_first_name` from `variables`; stop loading `@user` (the `user_id` argument stays in both signatures so callers are unchanged, no longer read).
- Per-stage mailer + its templates: untouched (single recipient, greeting stays correct).

Confirmed: "That's fine then" (both all-stages templates) + "Okay, no greeting at all. That's fine. Let's do it."

## Statement second sentence — skip reasons (both modals)

Both modals' Statement second sentence becomes: "Candidates without a resume, one that's still processing, or those already part of another bulk operation are skipped." Adds the third real skip reason (already claimed by another bulk operation — `QueueBulkAiSummaryJobs` excludes `BulkAiSummaryJobApplication.status_processing` claims in both paths) that the analog's sentence omits. Confirmed: "Confirm."

## Item 1 test scope — backend only, no frontend tests

Backend only: extend `spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb` for the new hiring-team recipient resolution (active members included, inactive excluded, both `complete` and `failed`). No frontend tests — Jessica never wanted frontend coverage; the old spec's "extend/add coverage for BulkGenerateAiSummariesConfirmModal" line was agent-written, not her ruling. Existing `queue_bulk_ai_summary_jobs_spec.rb` and `bulk_ai_job_application_summaries_controller_spec.rb` already cover `rescore_requested` threading on the shared enqueue path. Confirmed: "No, I never wanted front-end coverage... So I confirm."

## Query-invalidation difference between the two bulk hooks — untouched

`useBulkGenerateAllStagesAiSummaries` invalidates `"job"` on success; `useBulkGenerateAiSummaries` doesn't. Intentional ("There's a reason for that") — out of scope, leave untouched. Confirmed: "Yeah, leave that untouched."

## Item 2 — attribute name ratified

The virtual attribute name `ai_summary_rescore_requested` on `JobApplication` (shipped with the bulk work, never previously put to Jessica) stands. Confirmed: "Confirm."

## Item 2 — gate-4 change, only gate changed

The single gate change on the whole single-send path: `create_ai_summary_generation.rb:36` — currently `if active_ai_summary` (return existing active summary, enqueue nothing); becomes `if active_ai_summary && !job_application.ai_summary_rescore_requested`, mirroring `create_bulk_ai_summary_generation.rb:45`. With the attribute true, the interactor falls through to building a new pending `AiJobApplicationSummary` and enqueuing `GenerateAiJobApplicationSummaryJob`, exactly like a first generation. Zero edits to the other eight gates: controller existence/tenancy, Pundit `create?`, `ValidateAiSummaryGeneration` (flipper/resume/credits/description/textract), job entry check, `textract_result.rb:68` succeeded-and-not-stale return (self-resolves — the new pending row becomes `latest_ai_job_application_summary`), job-criteria readiness, `Orchestrate` entry checks, charge-on-success + `CreateAiCreditBalanceTransaction` balance check. Confirmed: "Okay, confirm gate for change."

## Item 2 — scope: one behavior only

Enable regenerating an `AiJobApplicationSummary` when `ai_summary_rescore_requested` is passed as true: the candidate already has a succeeded, non-stale summary; no new resume, no new textract result involved. The ONLY thing copied from the bulk interactor is the gate condition (`&& !job_application.ai_summary_rescore_requested`). The bulk interactor is the source for this one behavior, not a whole-file analog — no other behavior of either interactor is compared, ported, or surfaced (its extra stale block is its own business; its context differs). Method rule going forward: confirm the exact scope of an analog copy (whole structure vs single behavior) with Jessica at the start of analog work. Confirmed: "Yes."

## Item 2 — param threading (frontend param → controller strong params → attribute)

`GenerateParams` in `useAiJobApplicationSummary.ts` gains `rescoreRequested: boolean`, always sent — literal `false` at the plain-Generate callsite, `true` from Regenerate. `Api::V1::AiJobApplicationSummariesController#create` (currently no strong params) adds a params method: `params.require(:ai_job_application_summary)` then `.require(:rescore_requested)` (Rails `require` special-cases `false` as present — same reason the bulk controller's `require` works). The controller sets `job_application.ai_summary_rescore_requested = <value>` before `CreateAiSummaryGeneration.call` — same placement as the bulk path (attribute set on the record just before the interactor). Rationale: interactors do not enforce parameters; requiredness lives in strong params at the controller boundary. Confirmed: "Yes, the reason for this being that interactors do not enforce parameters."

## Item 2 — PlatoTab callsite wiring, exact shape pinned

`PlatoTab.tsx` `handleGenerate` gains a required boolean parameter `rescoreRequested` — no default value — and passes it into the mutation: `generate({ jobApplicationId: jobApplication.id, rescoreRequested })`. All four callsites pass the literal explicitly: the three `PlatoTabEmptyState` onClick paths (bulkQueued, failed, ready/noCredits) become `onClick={() => handleGenerate(false)}` (arrow-wrapped so the click event cannot ride in as a truthy argument); the Regenerate `ConfirmationModal` `onConfirm` calls `handleGenerate(true)` after its existing `removeModal()`. Spec pins this exact shape — implementing agent has no latitude. Confirmed: "Option 1: Pin it down."

## Spec-authoring rule — pin analog patterns verbatim in the spec

When an existing implementation pattern in an analog applies, the spec pins it down explicitly — exact identifiers, exact structure, verbatim strings — never "follow the analog" or "mirror X". Agents have proven unreliable at following analogs. Confirmed: "if there is a current existing implementation pattern in the analog, we should definitely pin it down in the spec."

## Item 2 — Regenerate button gating

`PlatoTab.tsx:247` header-right condition changes from `statusValue === "current" && fullSummary?.stale` to `statusValue === "current"` alone — Regenerate renders for every current review, stale or not. Everything inside the branch stays exactly as-is: the credits check (`isLoadingCredits || totalRemaining > 0`) choosing between the Regenerate button and the Buy-credits fallbacks (admin nav button / non-admin alert modal), the `ConfirmationModal`, and the button's `loading={buttonLoading} disabled={buttonLoading}` pairing. Confirmed: "Correct. Yes. Confirm."

## Item 2 — delete AiSummaryState.tsx

`app/javascript/ats/src/views/jobApplications/AiSummaryState.tsx` is deleted. Dead code — zero references anywhere in app/ or cypress/ (verified by grep; superseded by `PlatoTab.tsx`) — and making `rescoreRequested` required in `GenerateParams` would otherwise break its compile at its `generate({ jobApplicationId }, ...)` call. Confirmed: "Delete that file."

## Item 2 — two succeeded non-stale rows after re-score: intended behavior

After a successful re-score the candidate has two `AiJobApplicationSummary` rows with `status: succeeded, stale: false`; readers resolve the operative row by newest `created_at` or via the status record's `ai_job_application_summary_id`, so the older row is unreachable history. Accepted as working exactly as intended — not a consequence needing mitigation. Confirmed: "It works exactly as intended."

## Item 2 test scope — backend only

Extend the `CreateAiSummaryGeneration` interactor spec: with an active non-stale succeeded summary, `ai_summary_rescore_requested` true builds a new pending summary and enqueues `GenerateAiJobApplicationSummaryJob`; false returns the existing summary and enqueues nothing (mirrors the assertions in `create_bulk_ai_summary_generation_spec.rb`). Extend the `ai_job_application_summaries` controller spec: request without `rescore_requested` rejected; with it, value threads onto the record. No frontend tests. Regression detection only. Confirmed: "Sure, that's fine... you can add it to the test."

## Spec scope

The new spec covers the same two items as the old SPEC-plato-bulk-rescore-and-touchups.md: (1) the per-stage bulk "Run Plato reviews" trigger gets the re-score checkbox, (2) the single-send Regenerate can re-score an already-scored candidate. Confirmed: "yes, that's what we're doing."
