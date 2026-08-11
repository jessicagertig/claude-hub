# SPEC-REVIEW-COMPLETE — Plato re-score: per-stage bulk checkbox + single-send Regenerate

**Phase 2 (Iterative Adversarial Spec Review)**
**Date:** 2026-07-11
**Spec:** SPEC.md (amended in place, 3 accuracy amendments)
**Worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings` (`job-criteria-settings-qa`, HEAD f8815555a)

## Final verdict: READY FOR PLANNING — with ONE open owner-decision (see Escalation E1)

The adversarial review converged to two consecutive full passes (Rounds 2 and 3: zero MED+ findings, zero amendments). The spec is implementation-ready as amended. One product decision (the multi-recipient email greeting) is surfaced for Jessica to rule; it does not block planning but she asked to decide it herself.

---

## Plain English Summary

Polymer's "Plato" reviews AI-score job candidates against a role. Two small gaps are being closed. (1) When a recruiter bulk-runs Plato reviews on ONE hiring stage, they currently cannot ask it to re-review candidates who already have a review — the whole-job version already has that checkbox, so this adds the same checkbox to the per-stage version and rewrites the modal's wording (and its credit math) to match the whole-job modal. It also fixes some misleading wording in the whole-job modal, and changes the "all done" email so the whole hiring team gets it (today only the person who clicked does). (2) On a single candidate, the "Regenerate" button today only works if the resume changed; this makes it work any time a review exists, so a recruiter can re-run one candidate's review after changing the job's requirements. Each re-review costs one AI credit, same as a first review.

## Blast Radius Analysis

- **What changes:** one React modal gets a checkbox + reworded copy; a second React modal gets three copy fixes; one mailer widens its recipient list; one interactor gate gains one condition; one controller gains a strong-param; one hook type gains a required field; one component's four button-callsites pass a literal; one dead component is deleted.
- **Existing behavior changed:** per-stage bulk modal now can re-score; whole-job result email now goes to the whole active hiring team (both success and failure); single-send Regenerate now renders for every current review, not just stale ones.
- **Code modified:** `BulkGenerateAiSummariesConfirmModal.tsx`, `RunPlatoReviewAllModal.tsx`, `bulk_all_stages_ai_summary_result_mailer.rb`, `create_ai_summary_generation.rb` (one line), `ai_job_application_summaries_controller.rb`, `useAiJobApplicationSummary.ts`, `PlatoTab.tsx`; deleted `AiSummaryState.tsx`; specs `bulk_all_stages_ai_summary_result_mailer_spec.rb` (extend+reconcile), `create_ai_summary_generation_spec.rb` (new), controller spec (new).
- **Consumers/downstream:** `GenerateParams` becomes required-field — only consumers are `PlatoTab.tsx` (updated) and `AiSummaryState.tsx` (deleted); no survivor breaks. The shared bulk backend enqueue path is unchanged. The single-send generation job, credit charge, and status-record transitions are unchanged (the re-score reuses the first-generation path exactly).
- **If wrong:** blast is contained to the Plato tab and the two bulk "Run Plato reviews" modals plus their result email. Worst realistic failure is a modal miscount/miscopy or the result email reaching the wrong recipients — one workflow, not the app.

---

## Round-by-round outcomes

| Round | BLOCKER | HIGH | MED | LOW | Amendments | Verdict |
|---|---|---|---|---|---|---|
| 1 | 0 | 0 | 3 | 2 | 3 | FAIL |
| 2 | 0 | 0 | 0 | 1 new | 0 | PASS |
| 3 | 0 | 0 | 0 | 0 new | 0 | PASS |

Two consecutive full passes (Rounds 2-3). Loop terminated.

---

## Amendments and disagreements for Jessica

### (a) Inline amendments applied (accuracy fixes — no owner decision altered)

**A1 — SPEC 1.6 (mailer): retain `@user`.**
- Before: section ended at "…Guard `return unless recipients.any?` as in the analog mailer method." (silent on `@user`/`user_first_name`).
- After: added "Retain the existing `@user = User.find(user_id)` line in both methods — ONLY the `to:` array changes. The `variables` hash keeps `user_first_name: @user.first_name`, which continues to resolve from the triggering user." (plus the inline ESCALATION note in A/E1 below).
- Reason: the mailer's `variables` hash reads `@user.first_name`. SPEC 1.6 only broadened `to:`; an implementer could delete `@user` (now unused by `to:`) and break `user_first_name`. Accuracy: keep the variable populated. Does not contradict any approved decision (recipients decision was silent on the greeting variable).

**A2 — SPEC 1.7 (mailer spec): reconcile the pre-existing stale spec.**
- Before: "Extend `spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb`: active hiring-team members included, inactive members excluded, for both `complete` and `failed`."
- After: same, plus an explicit directive to reconcile the spec's four staleness points against the real mailer: (a) `#complete` call is 5-arg vs the 6-arg signature → add the missing `total` arg; (b) `#complete` subject/tags are `"Your AI summaries…"` / `['polymer','user-facing','ai-summaries']` but the mailer emits `"Your Plato reviews for #{@job.title} are ready"` / `['polymer','user-facing']`; (c) `#failed` subject is `"We couldn't generate AI summaries…"` but the mailer emits `"We couldn't complete your Plato reviews for #{@job.title}"`; (d) both examples assert a single recipient (`params[:to].first[:email]).to eq(user.email)`) → replace with multi-recipient assertions.
- Reason: this is the Phase-1-flagged known issue. The spec cannot pass as written (5-arg call → ArgumentError; wrong subject/tags). "Extend" without reconciling layers new assertions on already-failing expectations. Accuracy fix, not a decision change.

**A3 — SPEC 2.8 (interactor spec): double must stub `textract_pending: false`.**
- Before: "…the same assertion pairs `create_bulk_ai_summary_generation_spec.rb` makes for the bulk interactor"
- After: same, plus "NOTE: the `validation_result` double must ALSO stub `textract_pending: false`… Unlike the bulk interactor, `CreateAiSummaryGeneration` reads `validation_result.textract_pending` (`create_ai_summary_generation.rb:41`) on the fall-through (rescore-true) path; a double copied verbatim from the bulk spec (which omits it) would raise on the unstubbed message."
- Reason: the single-send interactor reads one field the bulk interactor does not. Mirroring the bulk spec's double verbatim would raise `RSpec::Mocks::MockExpectationError`. Accuracy fix to the test direction.

### (b) Disagreements NOT amended — decision-conflict escalations for Jessica

**E1 — SPEC 1.6: multi-recipient email greeting semantics.** With `@user` retained (A1), both `complete` and `failed` still pass `user_first_name = the TRIGGERING user's first name`, but the email now goes to the whole active hiring team. If the external Postmark templates `user-bulk-all-stages-ai-summary-complete` / `-failed` use `user_first_name` as a greeting, every teammate is greeted by the person who clicked, not by their own name. Per-recipient personalization is out of the spec's scope. I did not amend a behavior here because "what the greeting should say to a whole team" is a product decision, not an accuracy fix (borderline → escalate per your instruction). I could not verify how the templates use the variable — they are external, not in the repo.
- Options: (i) accept as-is (minimal change, everyone greeted by the trigger's name); (ii) change the greeting variable/template (e.g., drop the personal greeting for the team email) — this would add template work beyond the current spec.
- Recommendation: (i) is the minimal, spec-faithful behavior; confirm it's acceptable or rule (ii).

### (c) Findings considered and NOT raised as amendments (LOW / informational / rejected)

LOW observations kept open (not amended):
- **L1 (SPEC 1.2):** the restructured body copy does not pin the body-copy WRAPPER styled component. Current file uses `Styled.Instructions` (mb(5) + bold-span); the analog uses `Styled.Body` (mt(2), gray, line-height 1.5). Cosmetic + decision-adjacent (which visual wins). Not amended.
- **L2 (SPEC 1.5):** SPEC pins the checked-state all-stages sentence with `{candidatesCount}`; approved-decisions "flag A" wrote `{candidatesToScoreCount}`. Numerically identical when the checkbox is checked (`candidatesToScoreCount === candidatesCount`). No rendered difference. Not amended.
- **L3 (SPEC 1.6):** SPEC does not mention `.includes(:user)`; the analog uses it to avoid N+1. Optimization only; "resolved like JobApplicationMailer#hiring_team_new_job_application" arguably implies it. Not amended.
- **L4 (SPEC 2.2):** the param require is placed "before the interactor," i.e., AFTER `ValidateAiSummaryGeneration` — so a request MISSING `rescore_requested` runs validation (which can enqueue a textract job) before the ParameterMissing rejection, unlike the bulk controller which requires at the top of `create`. Negligible impact (frontend always sends the param; the wasted enqueue only affects a candidate with no textract on a malformed request). Owner approved the placement; not amended. If you want defensive early-reject, call the params method at the top of `create`.

Rejected as false positives against the scope guardrails (each considered, each dropped — one line):
- Diffing the two interactors wholesale / porting the bulk staleness-refresh block, `textract_pending` omission, or bulk's no-enqueue into the single-send interactor — guardrail 1. Rejected.
- Demanding React/Cypress tests for either item — guardrail 3. Rejected.
- The leading "The" on the per-stage checked sentence diverging from the all-stages sentence — owner-ruled (guardrail 2). Rejected.
- The mailer dropping `.receives_new_job_application_emails` — owner-ruled (SPEC 1.6). Rejected.
- The per-stage overestimate info block being absent from the all-stages analog — owner-ruled (SPEC 1.3). Rejected.
- The single-send controller not using `.permit` like the bulk controller — the scalar `.require().require()` is the owner-approved shape (guardrail priority rule). Rejected.
- Item 2 "missing job/serializer/policy" — the single-send path already has them and they are explicitly untouched (SPEC 2.1). Rejected.
- Regenerate button `loading` without `disabled` (known-failure #11) — the SPEC keeps the existing `loading={buttonLoading} disabled={buttonLoading}` pairing. Not a defect.

---

## Verification depth (for the record)

Every SPEC file:line reference was checked against the worktree and confirmed accurate (see reviews/spec-round-1/always-on-checks.md table). The Item 2 single-send re-score was traced end-to-end: controller → `ValidateAiSummaryGeneration` (not blocked for an already-scored candidate) → `CreateAiSummaryGeneration` gate → `textract_result.rb:68` self-resolution (new pending row becomes `latest_ai_job_application_summary`, so the succeeded-and-not-stale guard does not fire) → `FindOrCreateAiJobApplicationSummaryStatus` `current → regenerating → current` (regeneration_in_progress? is status-based, no stale check; prior score stays on screen). The pinned gate string, strong-params shape, all pinned Item 1 copy/styles, the FormCheckbox contract, and the zero-external-reference deletion of `AiSummaryState.tsx` were all confirmed.

## Open question for Jessica
1. E1 — the whole-team result email greeting (`user_first_name` = triggering user's name for all recipients): accept as-is, or change the greeting?
