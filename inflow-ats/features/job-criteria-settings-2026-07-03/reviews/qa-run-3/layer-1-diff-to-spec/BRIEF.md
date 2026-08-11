# Layer 1 Diff-to-Spec — Shared Agent Brief (qa-run-3)

## Why qa-run-3 exists
qa-run-2 converged Layers 1 (two clean rounds, 34 files) and 2 (two clean rounds), then Jessica made a code change mid-QA: the **regenerate authorization gate** changed from `update_ai_settings?`/`can_use_ai_credits?` to `JobPolicy#update?` (hiring-team member OR admin). Per the harness fix-loop rule, any code change restarts QA from Layer 1 in a new run. This is that new run.

The auth change is commit `859c85ead` and touches EXACTLY two files (+21/−2 vs the prior QA base `3e5aaf7c5`):
- `app/controllers/api/v1/ai_job_criteria_controller.rb` — `create` now does `authorize job, :update?` (was `authorize job, :update_ai_settings?`).
- `spec/controllers/api/v1/ai_job_criteria_controller_spec.rb` — two auth contexts: a hiring-team member without AI-credits control is ALLOWED on both `show` and `create`; a non-hiring-team, non-admin outsider is REJECTED (403) on `create`.

## Repo and diff
- Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings` (branch `job-criteria-settings-qa`, HEAD `859c85ead`)
- The implementation diff: `cd /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings && git diff develop...HEAD`
- 33 changed files (~+1717/−21). Scope your reads to your assigned area but you may read anything.

## Authority chain (highest wins)
1. `DECISIONS.md` (working dir: `/Users/jessica/claude-hub/inflow-ats/features/job-criteria-settings-2026-07-03/`) — wins over every design file. **The "Regenerate authorization = `JobPolicy#update?`" bullet IS the decision of record** (hiring-team member OR org admin; read access stays `show?`).
2. `SPEC.md` (same dir) — §9 was amended to the `update?` gate; §7 was amended post-conventions-pass to the fresh-read broadcast form (`AiJobCriteria.find_by(id: ...)` instead of `reload`). Read the spec as it stands on disk — both amendments ARE the spec now.
3. `reviews/plan-review.md` (Reviewed Plan section) and `plan.md`.
4. ORCHESTRATION-LOG.md proxy rulings and conventions-pass rulings (below) — implementations must MATCH these rulings. Do NOT re-adjudicate them.
5. `reviews/REVIEW-ANGLES.md` — background on review angles.

## The auth change is ADJUDICATED — matching implementation is NOT a finding
SPEC §9 (POST create → `authorize job, :update?`) and DECISIONS.md ("Regenerate authorization = `JobPolicy#update?`") both encode this. `JobPolicy#update?` = `on_hiring_team?` = `is_org_admin? || record.users.include?(user)` (`app/policies/job_policy.rb:20-22,58-60`). GET show stays `authorize job, :show?` (`job_policy.rb:12-14`: `(is_org_user? && current_organization_user.jobs.include record) || is_org_admin?`).

What a Layer-1 reviewer MUST still verify for the auth area (these ARE valid findings if wrong):
- The controller `create` actually calls `authorize job, :update?` (not the old `update_ai_settings?`, not `show?`, not a missing authorize).
- The controller `show` still calls `authorize job, :show?`.
- The spec's auth contexts actually exercise the `update?` semantics: hiring-team member (on the job's hiring team, no AI-credits control) allowed on create; a non-member non-admin rejected (403). A spec that claims to test this but stubs around it, or a context that would pass regardless of the gate, is a finding (ghost-test class).
- No OTHER file was changed by the auth commit beyond those two (scope creep = finding). Verified base delta is +21/−2 across exactly those two files.

## Other adjudicated rulings — matching implementations are NOT findings
Flags 1-7 (approved by the human-gate proxy, recorded in ORCHESTRATION-LOG.md):
1. `requesting_organization_user_id:` kwarg on `Job#extract_job_criteria_immediately` (SPEC §4.1).
2. Third zero-criteria message `'Criteria array is empty'` in `ZERO_CRITERIA_ERROR_MESSAGES` (SPEC §4.2).
3. Completion broadcast fires on failure too, not only success (SPEC §7).
4. `ExtractJobCriteriaJob` optional POSITIONAL second arg (NOT kwargs like the analog) — resolved: positional stands; kwargs cutover would break in-flight Sidekiq payloads.
5. Display precedence: failed latest row renders the failure/zero-found empty state over an older succeeded card (SPEC §8.2 rows 2/3 beat row 4).
6. `BulkGenerateAiSummariesJob#each_iteration` claim-row fix: validation failure → row `:failed` (SPEC §6.3) — in-spec reviewed scope.
7. Optional `job` context input on `QueueBulkAiSummaryJobs` (SPEC §6.2.3).

Develop-merge repair (documented in ORCHESTRATION-LOG.md "develop merge" rows — do not flag): test-only edits in `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb` adding `rescore_requested` to pre-existing examples and reshaping `params:` expectations. Develop's PR #3054 made `rescore_requested` required but left its own examples stale (red upstream); this branch repaired them during the merge. Adjudicated: traceable, not a finding.

Conventions-pass no-fix rulings (do not flag):
- `ai_job_criteria_controller.rb#create` renders the current payload with no interactor/result branch — adjudicated idempotent design per SPEC §5.2.
- `RegenerateJobCriteriaConfirmModal` owns its own mutation (not `ConfirmationModal`, not parent-owned) — adjudicated rule-22 analog pattern.

Conventions-pass fix batch (commit `9ed954142`; full text in `reviews/conventions-pass/CONVENTIONS-FAILURE-REPORT.md`) — these 8 changes trace to that adjudicated report and are IN-SPEC:
1. Fresh-read lookup in `broadcast_completion` (also now in SPEC §7 itself).
2. `Rails.logger.error` line in `bulk_generate_ai_summaries_job.rb` validation-failure branch.
3. Shared tier metadata constant file `app/javascript/ats/src/views/jobApplications/jobSetup/jobCriteriaTiers.ts`, consumed by both `JobSetupAiSettings.tsx` (sidebar) and `JobCriteriaSection.tsx`.
4. Query error state in `JobCriteriaSection.tsx`: on `isError`, failure-style EmptyState, title "Could not load job criteria", message "Something went wrong while loading job criteria. Refresh the page to try again.", NO action buttons; priority after `isLoading`, before payload states.
5. `border-radius` raw values → `${t.rounded.sm}` / `${t.rounded.md}` tokens.
6. Raw font-sizes → standalone `${t.text.sm}` / `${t.text.xs}` / `${t.text.base}` utilities.
7. `font-weight: 450` → `${t.text.medium}`.
8. Focus rings on `JobCriteriaViewModal` CloseButton and `JobCriteriaSection` SectionIntro `a`.

QA-run-1 fix batch (commit `3e5aaf7c5`; authority: `reviews/qa-run-1/layer-1-diff-to-spec/FAILURE-REPORT.md`) — adjudicated fixes, IN-SPEC:
1. `app/jobs/extract_job_criteria_job.rb:11` — exhaustion block calls `job.send(:broadcast_completion, ai_job_criteria, job.arguments.second)` (was a bare call that raised NoMethodError: `self` in a retry_on exhaustion block is the class). Only that one line changed in the job.
2. `spec/jobs/extract_job_criteria_job_spec.rb` — ONE new behavioral exhaustion example.
3. `components/JobCriteriaSection.tsx` — the intro "job description" link is a react-router `Link to={...}` (keyboard-focusable), replacing `<a onClick>`. SPEC §8.3's literal "via props.history.push" wording is superseded by this adjudicated fix — do NOT flag the Link form as a spec deviation.
The analog `generate_ai_job_application_summary_job.rb` is deliberately UNTOUCHED (its identical NoMethodError defect is out of scope, recorded as MED for Jessica).

## Round-1 adjudications (do not re-flag in later rounds)
- **`history: any` prop on `JobCriteriaSection` (JobCriteriaSection.tsx:22) + `history={props.history}` threading (JobSetupAiSettings.tsx:107)** — ADJUDICATED ACCEPTED. This is vestigial dead code from the qa-run-1 fix that swapped the intro `<a onClick={history.push}>` to a react-router `<Link>`. The qa-run-1 FAILURE-REPORT Finding 2 instruction was "do not change any other element," so the fix minimally removed `history` from the component's destructuring only, leaving the Props field + parent threading (minimal-fix discipline, pipeline rules 10/23). qa-run-2 L1 converged clean (11 agents, 2 rounds) with this exact state, explicitly documented as accepted ("Props.history and the parent's history prop untouched"). It is `any`-typed, never read, has ZERO runtime effect, and is NOT part of the auth delta. Optional cleanup for Jessica — NOT a convergence-blocking finding.
- **SPEC §12 line 513 wording** — CORRECTED by the orchestrator to match amended §9/DECISIONS (a hiring-team member without AI-credits control is ALLOWED on create; only a non-member non-admin is rejected). The prior "rejected on create" wording was stale pre-amendment text. The code + tests already follow amended §9 — not a code/test finding.

## Layer 1 rules
- **Every finding is HIGH.** No MED, no LOW, no "close enough", no "functionally equivalent".
- **Spec-to-diff:** every assigned spec requirement must have corresponding code in the diff. Missing = finding.
- **Diff-to-spec:** every change in your assigned area must trace to SPEC / DECISIONS / Reviewed Plan / an adjudicated ruling above. Untraceable = finding; report the FULL scope (every method/path, not one line).
- **Behavioral correctness:** for each mapped pair, read the code and confirm it does what the spec says. Don't just check the file was touched.
- **Constraints/edge cases:** verify the spec's edge cases for your area.
- **Ambiguity:** genuinely ambiguous spec → finding with a note.
- Read code in the worktree at the paths in the diff. Do NOT modify anything anywhere — you are read-only except for your one output file.

## Output
Write EXACTLY one file: `/Users/jessica/claude-hub/inflow-ats/features/job-criteria-settings-2026-07-03/reviews/qa-run-3/layer-1-diff-to-spec/round-{N}/agent-{M}.json` (N and M given in your dispatch prompt).

```json
{
  "layer": "diff-to-spec",
  "round": 1,
  "agent_index": 1,
  "focus_area": "...",
  "findings": [
    {
      "id": "l1-a{M}-001",
      "type": "VIOLATION",
      "title": "...",
      "spec_requirement": "SPEC §x.y: ...",
      "evidence": "file:line — what the code actually does",
      "recommendation": "..."
    }
  ],
  "spec_coverage": {
    "requirements_checked": ["SPEC §4.1", "..."],
    "implemented": 0,
    "missing": 0,
    "notes": "..."
  }
}
```

Empty findings array if your area fully matches. Your final chat message: one-paragraph summary + finding count.
